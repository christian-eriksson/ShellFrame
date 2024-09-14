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
    if [ "$number_of_inputs" -lt "2" ]; then
        return
    fi

    local completion_hint="${filtered_words[-1]}"
    [ -n "$completion_hint" ] && unset filtered_words[-1] && filtered_words+=("")

    local completions_file=($(_search_completion_file "completions" "${filtered_words[@]}"))
    local command_count=$(($number_of_inputs -1))
    if [ "$command_count" -eq 1 ]; then
        local executable_path=$(which "${filtered_words[0]}")
        local script_path=$(readlink $executable_path)
        local source_dir=$(realpath $(dirname "$script_path"))
        local completions_directory="$source_dir/commands/"
    else
        local completions_directory="${completions_file%completions.txt}commands"
    fi

    local completions=""
    if [ -n "$completions_directory" ] && [ -d "$completions_directory" ]; then
        local command_completions=$(find "$completions_directory/" -maxdepth 1 \
            -type f -executable -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' |
            tr "\n" " "
        )
        completions="$completions $command_completions"
    fi

    if [ -n "$completions_file" ] && [ -f "$completions_file" ]; then
        completions="$completions $(cat "$completions_file")"
    fi

    COMPREPLY=($(compgen -W "$completions" -- "$completion_hint"))
}

complete -F _cli_completions $CLI_NAME
