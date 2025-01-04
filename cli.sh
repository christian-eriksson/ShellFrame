#!/bin/bash

set -e -o pipefail

script_path=$(readlink "$0") || script_path="$0"
script_dir=$(realpath $(dirname "$script_path"))
usage_string="Usage: $(basename $0) [-h] [-e <ENVIRONMENT>] [-v] <COMMAND> [<OPTIONS>] [<INPUT>]"

_usage () {
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

shift $((OPTIND - 1))

command_executables="$(find -L $script_dir/commands/ -maxdepth 1 -perm -111 -not -type d -print)"

if [ -n "$help" ]; then
    echo \
    "$usage_string

Description:
This is a basic example of how to create a cli tool in Bash, it allows you to
extend it by adding executable shell scripts in the 'commands' directory of
the repo. to add a command called 'foo' to the cli, create the executable
file:

$script_dir/commands/foo.sh

The script needs to accept the '-h' flag and display a help text for the
command then exit if provided. And it must accept the '-v' flag, for verbose,
and execute normally if it is provided (with some extra logs if applicable).

Install the cli by soft linking the 'cli.sh' to some directory in
your path. For example:

ln -s $script_dir/cli.sh ~/.local/bin/cli

Assuming that '~/.local/bin' is in your \$PATH.

You can configure the cli with differente environments by adding one or multiple
'.env.<ENVIRONMENT>' files in this directory:

$script_dir

The commands will all be able to read the variables set in this file and you can
use the '-e' flag to choose which file to use.

Options:
  -e  <ENVIRONMENT> Selects the environment to run in, default environment is
                    'dev'. If no .env.* file exists, variables need to be
                    provided manually. Variables defined in .env.* takes
                    precedence over environment variables provided through other
                    means.
  -v                Verbose output, use for debugging.
  -h                Show this help text

  <COMMAND>         The command to be executed, see the available commands below
  <OPTIONS>         The options to send to the command, see the options in the
                    individual help sections for each command.
  <INPUT>           The input to the command, see the section for each command
                    to read about their input.

Commands:
    "

    echo "$command_executables" | while read -r file; do
        filename=$(basename $file)
        printf -- "- %s\n" "${filename%.*}"
    done
    find $script_dir/commands/ -ipath .*-help.txt | while read -r file; do
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

    find $script_dir/commands/ -ipath "*-help.txt" | while read -r file; do
        filename=$(basename $file)
        command=${filename%-help.txt}
        command_file=$(find $script_dir/commands/ -iname ${command}.*)
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
    sub_command_path="$script_dir/commands"
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
        command_executable=$(_find_executable "$script_dir/commands" "$command") || true
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
        if ! . $script_dir/.env.$environment 2>/dev/null; then
            echo "ERROR: could not load config: '$script_dir/.env.$environment'!!!"
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
        echo $help_file
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
    [ -n "$verbose" ] && echo "command file does not exist or is not executable"
    echo "ERROR: '$command' is not a command"
    _usage
fi
