#/bin/bash

[ -z "$CLI_NAME" ] && echo "ERROR: could not load cli completions" && return 1

_cli_completions()
{
    number_of_inputs="${#COMP_WORDS[@]}" # including space after last command

    # 1st (base) command is not finished
    if [ "$number_of_inputs" -lt "2" ]; then
        return
    fi

    local executable_path=$(which "${COMP_WORDS[0]}")
    local script_path=$(readlink $executable_path)
    local source_dir=$(realpath $(dirname "$script_path"))

    # base command finished, looking for first set of sub-commands
    if [ "$number_of_inputs" -eq "2" ]; then
        COMPREPLY=($(compgen -W "$(find "$source_dir/commands/" -maxdepth 1 -type f -executable -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' | tr "\n" " ")" -- "${COMP_WORDS[1]}"))
    fi

    # first set of sub-commands finished, on n-th level, looking for 1+n-th
    # level of sub-commands
    if [ "$number_of_inputs" -gt "2" ]; then
        local base_sub_commands_dir="$source_dir/commands"
        local nth_sub_command_level=$(($number_of_inputs -1))
        local nth_plus_one_sub_command_dir=$base_sub_commands_dir
        local nth_sub_command_dir=$base_sub_commands_dir
        local command_completion_file=""
        local i=1
        local counter=1
        while [ $i -lt $nth_sub_command_level ]; do
            if [ -d "$nth_plus_one_sub_command_dir/${COMP_WORDS[$i]}-commands" ]; then
                nth_plus_one_sub_command_dir="$nth_plus_one_sub_command_dir/${COMP_WORDS[$i]}-commands"
                if [ $i -lt $(($nth_sub_command_level - 1)) ]; then
                    nth_sub_command_dir="$nth_sub_command_dir/${COMP_WORDS[$i]}-commands"
                fi
                counter=$(($counter + 1))
            else
                command_completion_file="$command_completion_file${COMP_WORDS[$i]}-"
            fi
            i=$(($i + 1))
        done

        local completions=""
        if [ $counter -eq $nth_sub_command_level ] && [ -d "$nth_plus_one_sub_command_dir" ]; then
            completions="$completions $(find "$nth_plus_one_sub_command_dir/" -maxdepth 1 -type f -executable -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' | tr "\n" " ")"
        fi

        current_command="${COMP_WORDS[$(($nth_sub_command_level - 1))]}"
        sub_command_completion_file="$nth_sub_command_dir/$current_command-completions.txt"
        if [ $counter -ge $(($nth_sub_command_level - 1)) ] && [ -f "$sub_command_completion_file" ]; then
            completions="$completions $(cat "$sub_command_completion_file")"
        fi

        multi_sub_command_completion_file="$nth_sub_command_dir/${command_completion_file}completions.txt"
        if [ -f "$multi_sub_command_completion_file" ]; then
            completions="$completions $(cat "$multi_sub_command_completion_file")"
        fi

        COMPREPLY=($(compgen -W "$completions" -- "${COMP_WORDS[$nth_sub_command_level]}"))
    fi
}

complete -F _cli_completions $CLI_NAME
