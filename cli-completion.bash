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
    local counter=0
    for command in "${raw_command_chain[@]}"; do
        [ -z "$command" ] && break
        [ "$counter" -eq 0 ] && counter=$(($counter + 1)) && continue
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
        counter=$(($counter + 1))
        if [ "$counter" -eq $(("${#raw_command_chain[@]}" -1)) ]; then
            local second_to_last_option=$file_path
        fi
    done
    local base_path="${file_path%commands\/}"
    file_path="$base_path$file_type.txt"
    if [ ! -f "$file_path" ]; then
        file_path="$second_to_last_option"
    fi
    echo "${file_path}"
}

_cli_completions() {
    local filtered_words=()

    for word in "${COMP_WORDS[@]}"; do
        if [[ "$word" != -* ]]; then
            filtered_words+=("$word")
        fi
    done
    local number_of_inputs="${#filtered_words[@]}"

    # 1st (base) command is not finished
    if [ "$number_of_inputs" -lt "2" ]; then
        return
    fi

    local executable_path=$(which "${filtered_words[0]}")
    local script_path=$(readlink $executable_path)
    local source_dir=$(realpath $(dirname "$script_path"))

    # base command finished, looking for first set of sub-commands
    if [ "$number_of_inputs" -eq "2" ]; then
        COMPREPLY=($(compgen -W "$(find "$source_dir/commands/" -maxdepth 1 -type f -executable -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' | tr "\n" " ")" -- "${filtered_words[1]}"))
        return
    fi

    # first set of sub-commands finished, on n-th level, looking for 1+n-th
    # level of sub-commands
    if [ "$number_of_inputs" -gt "2" ]; then
        local command_count=$(($number_of_inputs -1))

        local completions_file=($(_search_completion_file "completions" "${filtered_words[@]}"))
        local completions_directory="${completions_file%completions.txt}commands"
        if [ ! -d "$completions_directory" ] && [ ! -f "$completions_file" ]; then
            case "$completions_file" in
                */)
                    completions_directory=$completions_file
                    completions_file="${completions_file%commands\/}completions.txt"
                ;;
                *)
                    completions_file="${completions_file}completions.txt"
                ;;
            esac
        fi

        local completions=""
        if [ -n "$completions_directory" ] && [ -d "$completions_directory" ]; then
            completions="$completions $(find "$completions_directory/" -maxdepth 1 -type f -executable -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' | tr "\n" " ")"
        fi

        if [ -n "$completions_file" ] && [ -f "$completions_file" ]; then
            completions="$completions $(cat "$completions_file")"
        fi

        COMPREPLY=($(compgen -W "$completions" -- "${filtered_words[$command_count]}"))
    fi
}

complete -F _cli_completions $CLI_NAME
