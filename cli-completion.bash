#/bin/bash

[ -z "$CLI_NAME" ] && echo "ERROR: could not load cli completions" && return 1

# will stop searching if it finds any flags, so filter flags before searching
# for sub-commands
_search_completion_file() {
    local file_type="$1"
    shift
    local raw_command_chain=("$@")
    local executable_path=$(which "${raw_command_chain[0]}")
    local script_path=$(readlink $executable_path)
    local source_dir=$(realpath $(dirname "$script_path"))

    local file_path="$source_dir/commands/"
    local past_first="false"
    for command in "${raw_command_chain[@]}"; do
        [ -z "$command" ] && break
        [ "$past_first" = "false" ] && past_first="true" && continue
        case "$command" in
            -*)
                break
            ;;
            *)
                if [ -d "$file_path$command-commands" ]; then
                    file_path="$file_path$command-commands/"
                else
                    file_path="$file_path$command-"
                fi
            ;;
        esac
    done
    local base_path="${file_path%commands\/}"
    file_path="$base_path$file_type.txt"
    echo "${file_path}"
}

_cli_completions() {
    local filtered_words=()

    local word_counter="0"
    local flag_filtered_at_position="0"
    for word in "${COMP_WORDS[@]}"; do
        word_counter=$(($word_counter + 1))
        if [[ "$word" != -* ]]; then
            filtered_words+=("$word")
        else
            flag_filtered_at_position="$word_counter"
        fi
    done
    if [ "$flag_filtered_at_position" -eq  "${#COMP_WORDS[@]}" ]; then
        filtered_words+=("");
    fi
    local number_of_inputs="${#filtered_words[@]}"

    # 1st (base) command is not finished
    if [ "$number_of_inputs" -lt "2" ]; then
        return
    fi

    local completion_hint="${filtered_words[-1]}"
    local executable_path=$(which "${filtered_words[0]}")
    local script_path=$(readlink $executable_path)
    local source_dir=$(realpath $(dirname "$script_path"))

    # base command finished, looking for first set of sub-commands
    if [ "$number_of_inputs" -eq "2" ]; then
        COMPREPLY=($(compgen -W "$(find "$source_dir/commands/" -maxdepth 1 -type f -executable -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' | tr "\n" " ")" -- "$completion_hint"))
        return
    fi

    # first set of sub-commands finished, on n-th level, looking for 1+n-th
    # level of sub-commands
    if [ "$number_of_inputs" -gt "2" ]; then
        local command_count=$(($number_of_inputs -1))

        unset filtered_words[-1]
        local completions_file=($(_search_completion_file "completions" "${filtered_words[@]}"))
        local completions_directory="${completions_file%completions.txt}commands"

        local completions=""
        if [ -n "$completions_directory" ] && [ -d "$completions_directory" ]; then
            completions="$completions $(find "$completions_directory/" -maxdepth 1 -type f -executable -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' | tr "\n" " ")"
        fi

        if [ -n "$completions_file" ] && [ -f "$completions_file" ]; then
            completions="$completions $(cat "$completions_file")"
        fi

        COMPREPLY=($(compgen -W "$completions" -- "$completion_hint"))
    fi
}

complete -F _cli_completions $CLI_NAME
