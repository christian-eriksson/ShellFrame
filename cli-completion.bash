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

    local chain_length="${#raw_command_chain[@]}"
    if [ "$chain_length" -eq "2" ]; then
        local script_file=$(basename $script_path)
        local script_name="${script_file%.*}"
        file_path="$source_dir/$script_name-$file_type.txt"
        [ -f "$file_path" ] && echo "$file_path" ||  echo ""
        return
    fi

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
    local commands_provided=()
    local word_counter="0"
    local flag_filtered_at_position="0"
    local flags_to_current_command=()
    local last_flag_piece=""
    for word in "${COMP_WORDS[@]}"; do
        word_counter=$(($word_counter + 1))
        if [[ "$word" != -* ]]; then
            commands_provided+=("$word")
            [ -n "$word" ] && flags_to_current_command=()
        else
            if [ "${#word}" -eq "2" ]; then
                flags_to_current_command+=("$word")
            fi
            parital_flag_at_position="$word_counter"
            last_flag_piece=$word
        fi
    done
    local flag_hint=""
    if [ "$parital_flag_at_position" -eq  "${#COMP_WORDS[@]}" ]; then
        flag_hint="$last_flag_piece"
        commands_provided+=("");
    fi

    local number_of_commands="${#commands_provided[@]}"
    if [ "$number_of_commands" -lt "2" ]; then
        return
    fi

    local completion_hint="${commands_provided[-1]}"
    [ -n "$flag_hint" ] && completion_hint="$flag_hint"
    [ -n "$completion_hint" ] && unset commands_provided[-1] && commands_provided+=("")

    local flag_completions_file=($(_search_completion_file "flags" "${commands_provided[@]}"))
    local completions=""
    if [ -f "$flag_completions_file" ]; then
        completions="$completions $(cat "$flag_completions_file")"
    fi

    # We don't want to remove the flag we are potentially about to provide,
    # as something like 'cli -v -h{tab}' will not be auto completed if '-h' is
    # removed from the completion list. So we only remove if we are starting a
    # new flag or are not providing a flag.
    if [ "$completion_hint" = "-" ] || [ -z "$flag_hint" ]; then
        for flag in "${flags_to_current_command[@]}"; do
            completions=${completions/$flag/}
        done
    fi

    if [ -n "$flag_hint" ]; then
        COMPREPLY=($(compgen -W "$completions" -- "$completion_hint"))
        return
    fi

    local completions_file=($(_search_completion_file "completions" "${commands_provided[@]}"))
    local command_count_wo_completion_hint=$(($number_of_commands -1))
    if [ "$command_count_wo_completion_hint" -eq 1 ]; then
        local executable_path=$(which "${commands_provided[0]}")
        local script_path=$(readlink $executable_path)
        local source_dir=$(realpath $(dirname "$script_path"))
        local completions_directory="$source_dir/commands/"
    else
        local completions_directory="${completions_file%completions.txt}commands"
    fi

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
