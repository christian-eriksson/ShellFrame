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

command_executables="$(find $script_dir/commands/ -maxdepth 1 -type f -perm -111 -print)"

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

    echo "$command_executables" | while read -r file; do
        [ ! -x "$file" ] && continue
        filename=$(basename $file)
        command=${filename%.*}
        echo -e "\n${command^^}\n"
        "$file" -h
    done
    exit 0
fi

command=$1
shift || (echo "ERROR: no command provided!" && _usage)

command_path="$(echo "$command_executables" | grep "$command\.[[:alnum:]]\+$")" || true
[ -z "$command_path" ] && command_path="$script_dir/commands/$command"

_run_command() {
    set -a
    if [ -n "${environment}" ]; then
        if ! . $script_dir/.env.$environment 2>/dev/null; then
            echo "ERROR: could not load config: '$script_dir/.env.$environment'!!!"
            exit 64
        fi
    fi
    set +a
    "$command_path" $verbose "$@"
}

if [ -x "$command_path" ]; then
    [ -n "$verbose" ] && echo "running command: $command_path"
    [ -n "$verbose" ] && echo "with arguments: $verbose $@"
    (_run_command "$@") || ([ "$?" -eq 64 ] && _usage)
else
    [ -n "$verbose" ] && echo "command file does not exist or is not executable"
    echo "ERROR: '$command' is not a command"
    _usage
fi
