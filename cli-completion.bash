#/bin/bash

[ -z "$CLI_NAME" ] && echo "ERROR: could not load cli completions" && return 1

# will stop searching if it finds any flags, so filter flags before searching
# for sub-commands
_base_dir() {
    local dir="$1"
    if [ -f "$dir/.base-dir" ]; then
        local override=$(cat "$dir/.base-dir")
        [ "${override:0:1}" != "/" ] && override="$dir/$override"
        realpath "$override"
    else
        echo "$dir"
    fi
}

_search_completion_file() {
    local file_type="$1"
    shift
    local commands=("$@")
    local executable_path=$(which "${commands[0]}")
    local script_path=$(readlink $executable_path)
    local source_dir=$(_base_dir $(realpath $(dirname "$script_path")))

    if [ "${#commands[@]}" -eq "1" ]; then
        local script_file=$(basename $script_path)
        local script_name="${script_file%.*}"
        file_path="$source_dir/$script_name-$file_type.txt"
        [ -f "$file_path" ] && echo "$file_path" || echo ""
        return
    fi

    local file_path="$source_dir/commands/"
    unset commands[0]
    for command in "${commands[@]}"; do
        [ -z "$command" ] && continue
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
    file_path="${file_path%commands\/}$file_type.txt"
    echo "${file_path}"
}

_cli_completions() {
    local input_array=("${COMP_WORDS[@]}")
    local completion_hint="${input_array[-1]}"
    unset input_array[-1]

    local commands_provided=()
    local flags_to_current_command=()
    local flag_argument_hint=""
    # -e is usable at any command depth and only needs to be provided once
    # for the whole invocation, so track it separately - unlike
    # flags_to_current_command, this must NOT reset when a new command word
    # is encountered.
    local e_flag_provided=false
    for word in "${input_array[@]}"; do
        [ -z "$word" ] && continue
        if [[ "$word" = -* ]]; then
            flags_to_current_command+=("$word")
            [ "$word" = "-e" ] && e_flag_provided=true
            local flag_completions_file=($(_search_completion_file "flags" "${commands_provided[@]}"))
            local flag_completions=""
            [ -f "$flag_completions_file" ] && flag_completions="$(cat "$flag_completions_file")"
            # -e <ENVIRONMENT> is the only CLI-wide flag cli.sh accepts at any
            # command depth (see cli.sh); -v/-h are only accepted in leading
            # position, so don't offer them here - only merge in -e.
            local global_flags_file=($(_search_completion_file "flags" "${commands_provided[0]}"))
            if [ -f "$global_flags_file" ] && [ "$global_flags_file" != "$flag_completions_file" ]; then
                local global_e_flag=$(grep -e "^-e\*\? " "$global_flags_file") || true
                [ -n "$global_e_flag" ] && flag_completions="$flag_completions
$global_e_flag"
            fi
            [ -z "$flag_completions" ] && continue
            flag_argument_hint=$(echo "$flag_completions" | grep -e "${flags_to_current_command[-1]}\*\? " | cut -d" " -f2-) || true
        else
            if [ -n "$flag_argument_hint" ]; then
                flag_argument_hint=""
                continue
            fi
            commands_provided+=("$word")
            flags_to_current_command=()
        fi
    done

    flag_completions_file=($(_search_completion_file "flags" "${commands_provided[@]}"))
    local completions=""
    # A flag line ending in '*' (before the hint, if any) marks that flag as
    # required - collect these so we know when it's safe to also offer
    # positional-argument completions (see has_defined_completions below).
    local required_flags=()
    if [ -f "$flag_completions_file" ]; then
        completions="$completions $(cat "$flag_completions_file" | cut -d" " -f1 | sed 's/\*$//')" || true
        required_flags=($(cat "$flag_completions_file" | cut -d" " -f1 | grep -e '\*$' | sed 's/\*$//'))
    fi
    # -e <ENVIRONMENT> is the only CLI-wide flag cli.sh accepts at any command
    # depth (see cli.sh); -v/-h are only accepted in leading position, so
    # don't offer them here - only merge in -e.
    global_flags_file=($(_search_completion_file "flags" "${commands_provided[0]}"))
    if [ -f "$global_flags_file" ] && [ "$global_flags_file" != "$flag_completions_file" ]; then
        global_e_flag=$(grep -e "^-e\*\? " "$global_flags_file") || true
        [ -n "$global_e_flag" ] && completions="$completions $(echo "$global_e_flag" | cut -d" " -f1 | sed 's/\*$//')"
    fi
    # -e can end up listed twice above (once from the local flags file, once
    # from the global merge), which would otherwise survive the "remove
    # already provided flags" step below since it only strips one occurrence
    # per use. Dedupe so every flag name appears once.
    completions=$(echo "$completions" | tr " " "\n" | awk 'NF && !seen[$0]++' | tr "\n" " ")

    if [ -n "$flag_argument_hint" ]; then
        # A hint that is one or more pipe-separated choices with no spaces
        # (e.g. 'foo|bar|baz', or a single bare value like 'foo') is treated
        # as an enum: offer the values as real, tab-completable/cycleable
        # completions instead of just displaying.
        if [[ "$flag_argument_hint" =~ ^[^[:space:]]+(\|[^[:space:]]+)*$ ]]; then
            COMPREPLY=($(compgen -W "${flag_argument_hint//|/ }" -- "$completion_hint"))
            return 0
        fi
        if [ -z "$ZSH_VERSION" ]; then
            COMPREPLY=("$flag_argument_hint" "")
        fi
        return 0
    fi

    # We don't want to remove the flag we are potentially about to provide,
    # as something like 'cli -v -h{tab}' will not be auto completed if '-h' is
    # removed from the completion list. So we only remove if we are starting a
    # new flag or are not providing a flag.
    if ! ([[ "$completion_hint" = -* ]] && [ "${#completion_hint}" -eq 2 ]); then
        for flag in "${flags_to_current_command[@]}"; do
            completions=${completions/$flag/}
        done
        [ "$e_flag_provided" = true ] && completions=${completions/-e/}
    fi

    if [[ "$completion_hint" = -* ]]; then
        COMPREPLY=($(compgen -W "$completions" -- "$completion_hint"))
        return
    fi

    local completions_file=($(_search_completion_file "completions" "${commands_provided[@]}"))
    if [ "${#commands_provided[@]}" -eq 1 ]; then
        local executable_path=$(which "${commands_provided[0]}")
        local script_path=$(readlink $executable_path)
        local source_dir=$(_base_dir $(realpath $(dirname "$script_path")))
        local completions_directory="$source_dir/commands/"
    else
        local completions_directory="${completions_file%completions.txt}commands"
    fi

    local has_defined_completions=false
    if [ -n "$completions_directory" ] && [ -d "$completions_directory" ]; then
        local command_completions=$(
            find -L "$completions_directory/" -maxdepth 1 \
                -perm -111 -not -type d -execdir sh -c 'f=$(basename $0); printf "%s\n" "${f%.*}"' {} ';' |
                tr "\n" " "
        )
        completions="$completions $command_completions"
        has_defined_completions=true
    fi

    if [ -n "$completions_file" ] && [ -f "$completions_file" ]; then
        completions="$completions $(cat "$completions_file")"
        has_defined_completions=true
    fi

    local missing_required_flags=()
    for required_flag in "${required_flags[@]}"; do
        local required_flag_provided=false
        [ "$required_flag" = "-e" ] && [ "$e_flag_provided" = true ] && required_flag_provided=true
        for used_flag in "${flags_to_current_command[@]}"; do
            [ "$used_flag" = "$required_flag" ] && required_flag_provided=true && break
        done
        [ "$required_flag_provided" = false ] && missing_required_flags+=("$required_flag")
    done

    local matches=($(compgen -W "$completions" -- "$completion_hint"))
    if [ "$has_defined_completions" = false ] && [ "${#missing_required_flags[@]}" -eq 0 ]; then
        # There is no sub-commands directory or completions file defined for
        # this command - it expects a free-form positional argument (e.g.
        # <path-to-file>). Merge in real filesystem paths alongside any still-
        # available optional flags, so leftover unused optional flags don't
        # "block" reaching path completion (bash auto-inserts a single
        # remaining match instead of listing paths). Only do this once all
        # required flags have been provided, so files aren't mixed in with
        # flags the user still needs to supply.
        matches+=($(compgen -f -- "$completion_hint"))
    fi

    COMPREPLY=("${matches[@]}")
}

# -o filenames tells bash's readline that COMPREPLY entries may be paths, so it
# appends '/' (and suppresses the trailing space) for directory matches
# instead of treating every match as a "finished" word - without this,
# tab-completing into a directory ends the completion instead of letting you
# keep completing deeper into the path.
complete -F _cli_completions -o filenames $CLI_NAME
