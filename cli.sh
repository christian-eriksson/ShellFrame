#!/bin/bash

set -e -o pipefail

script_path=$(readlink "$0") || script_path="$0"
script_dir=$(realpath $(dirname "$script_path"))
script_file=$(basename $script_path)
script_name=${CLI_NAME:-${script_file%.*}}

# base_dir is where commands/, *-usage.txt, *-help.txt and .env.* are looked
# up. Defaults to script_dir but can be redirected to an external directory
# (e.g. when this repo is used as a git submodule) via a '.base-dir' file
# placed next to this script, containing a single path (absolute, or relative
# to script_dir).
base_dir="$script_dir"
if [ -f "$script_dir/.base-dir" ]; then
    base_dir=$(cat "$script_dir/.base-dir")
    [ "${base_dir:0:1}" != "/" ] && base_dir="$script_dir/$base_dir"
    base_dir=$(realpath "$base_dir")
fi

usage_file="$base_dir/$script_name-usage.txt"
if [ -f "$usage_file" ]; then
    usage_string=$(sed "s%{CLI_NAME}%$(basename $0)%" $usage_file)
else
    usage_string="Usage: $(basename $0) [-h] [-e <ENVIRONMENT>] [-v] <COMMAND> [<OPTIONS>] [<INPUT>]"
fi

_usage() {
    echo "$usage_string"
    exit 64
}

while getopts ":e:vh" opt; do
    case $opt in
    e)
        environment=$OPTARG
        ;;
    v)
        verbose=-v
        ;;
    h)
        help=-h
        ;;
    \?)
        echo "Invalid option: '-$OPTARG'" >&2
        _usage
        ;;
    :)
        echo "Option '-$OPTARG' requires an argument." >&2
        _usage
        ;;
    esac
done

shift $((OPTIND - 1)) # remove options from positional parameters

command_executables="$(find -L $base_dir/commands/ -maxdepth 1 -perm -111 -not -type d -print)"

if [ -n "$help" ]; then
    echo $usage_string
    help_file="$base_dir/$script_name-help.txt"
    if [ -f "$help_file" ]; then
        printf -- "\n"
        cat "$help_file"
    fi
    echo -e "\nCommands:\n"
    echo "$command_executables" | while read -r file; do
        filename=$(basename $file)
        printf -- "- %s\n" "${filename%.*}"
    done
    find $base_dir/commands/ -ipath .*-help.txt | while read -r file; do
        filename=$(basename $file)
        printf -- "- %s\n" "${filename%-help.txt}"
    done

    echo "$command_executables" | while read -r file; do
        [ ! -x "$file" ] && continue
        filename=$(basename $file)
        command=${filename%.*}
        echo -e "\n# ${command^^}\n"
        directory=$(dirname $file)
        help_file="${directory}/${command}-help.txt"
        if [ -f "$help_file" ]; then
            cat $help_file
            printf -- "\n"
        else
            "$file" -h
        fi
    done

    find $base_dir/commands/ -ipath "*-help.txt" | while read -r file; do
        filename=$(basename $file)
        command=${filename%-help.txt}
        command_file=$(find $base_dir/commands/ -iname ${command}.*)
        if [ -z "${command_file}" ]; then
            echo -e "\n# ${command^^}\n"
            cat $file
        fi
    done
    printf -- "\n"
    exit 0
fi

command=$1
shift || (echo "ERROR: no command provided!" && _usage)

_find_executable() {
    find -L $1/ -maxdepth 1 -iname "${2}.*" -perm -111 -not -type d -print |
        grep "${2}\.[[:alnum:]]\+$"
}

_find_command() {
    [ -n "$verbose" ] && echo "searching for command: '$command'"
    arguments=("$@")
    sub_commands=()
    for arg in "${arguments[@]}"; do
        [ -z "$arg" ] && continue
        case "$arg" in
        -*)
            break
            ;;
        *)
            sub_commands+=($arg)
            ;;
        esac
    done
    sub_command_path="$base_dir/commands"
    sub_command=$command
    idx=0
    while [ -d "$sub_command_path/$sub_command-commands" ]; do
        sub_command_path=$sub_command_path/$sub_command-commands
        sub_command="${sub_commands[$idx]}"
        [ -n "$verbose" ] && echo "searching for sub command '$sub_command' in: '$sub_command_path'"
        idx=$((idx + 1))
    done

    command_executable=$(_find_executable "$sub_command_path" "$sub_command") || true
    if [ -z "$command_executable" ]; then
        [ -n "$verbose" ] && echo "WARNING: no command executable found for sub command '$sub_command' at '$sub_command_path'!" || true
        command_executable=$(_find_executable "$base_dir/commands" "$command") || true
    fi
    if [ -z "$command_executable" ]; then
        if [ "$idx" -gt "0" ]; then
            echo "ERROR: no command executable found for sub command '$sub_command' at '$sub_command_path'!"
        fi
        echo "ERROR: no command executable found for command '$command' at '$command_path'!"
        exit 1
    fi
    while [ "$idx" -gt "0" ] && [ -n "$sub_command" ]; do
        idx=$((idx - 1))
        unset arguments[$idx]
    done
    command_path=$command_executable

    [ -n "$verbose" ] && echo "found command path: '$command_path'" || true
}

_find_command "$@" || _usage

_run_command() {
    set -a
    if [ -n "${environment}" ]; then
        if ! . $base_dir/.env.$environment 2>/dev/null; then
            echo "ERROR: could not load config: '$base_dir/.env.$environment'!!!"
            exit 64
        fi
    fi
    set +a
    arguments=("$@")

    for arg in "${arguments[@]}"; do
        if [ "$arg" == "-h" ]; then
            help=$arg
        fi
    done

    if [ -n "$help" ]; then
        command_file=$(basename $command_path)
        command=${command_file%.*}
        command_dir=$(dirname $command_path)
        help_file="${command_dir}/${command}-help.txt"
        if [ -f "$help_file" ]; then
            cat $help_file
            printf -- "\n"
        else
            "$command_path" -h
        fi
    else
        if [ -d "$command_path" ]; then
            echo "ERROR: no sub command in path '$command_path'!" && exit 64
        fi
        "$command_path" $verbose "${arguments[@]}"
    fi
}

if [ -x "$command_path" ] || ([ -L "$command_path" ] && [ -x "$(readlink $command_path)" ]); then
    [ -n "$verbose" ] && echo "running command: $command_path"
    [ -n "$verbose" ] && echo "with arguments: $verbose ${arguments[@]}"
    (_run_command "${arguments[@]}") || ([ "$?" -eq 64 ] && _usage)
else
    [ -n "$verbose" ] && echo "command file '$command_path' does not exist or is not executable"
    echo "ERROR: '$command' is not a command"
    _usage
fi
