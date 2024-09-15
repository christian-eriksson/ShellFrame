#!/bin/bash

set -e -o pipefail

script_dir=$(realpath $(dirname "$0"))
filename=$(basename "$0")
command=${filename%.*}
usage_string="${filename%.*} [-v] [-h] -e <NAME> <DIRECTION>"
_usage () {
    echo "command: $usage_string"
    exit 64
}

while getopts ":vhe:" opt; do
    case $opt in
        v)
            verbose=-v
            echo "running echo command"
        ;;
        h)
            help=-h
        ;;
        e)
            vehicle=$OPTARG
        ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            _usage
        ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            _usage
        ;;
    esac
done

shift $((OPTIND - 1))

commands_dir="$script_dir/${command}-commands"
if [ -n "$help" ]; then
    echo \
    "Usage: $usage_string

Description:
Takes you in new directions.

Options:
  -v                        Verbose output, use for debugging.
  -h                        Show this help text
  -e <NAME>     (required)  The vehicle that will be going in some direction

  <DIRECTION>               The direction you want to go in. Valid directions
                            are 'left' and 'right'

Direction Commands:
    "

    find "$commands_dir/" -type f -perm -111 -print | while read -r file; do
        sub_filename=$(basename "$file")
        sub_command=${sub_filename%.*}
        printf -- "- %s\n" "$sub_command"
    done

    for file in $commands_dir/*; do
        [ ! -x "$file" ] && continue
        [ ! -f "$file" ] && continue
        sub_filename=$(basename "$file")
        sub_command=${sub_filename%.*}
        echo -e "\n${command^^} ${sub_command^^}\n"
        "$file" -h
    done

    exit 0
fi

[ -z "$vehicle" ] && echo "missing vehicle name!" && _usage
[ -n "$verbose" ] && echo "provided vehicle: $vehicle"

direction=$1
shift || _usage
[ -n "$verbose" ] && echo "selected direction: $direction"

case "$direction" in
    "left")
        [ -n "$verbose" ] && echo "going 'left'"
        left=$($commands_dir/left.sh "$@")
        echo "The $vehicle goes to $left"
    ;;
    "right")
        [ -n "$verbose" ] && echo "going 'right'"
        right=$($commands_dir/right.sh "$@")
        echo "The $vehicle goes to $right"
    ;;
    "up")
        [ -n "$verbose" ] && echo "going 'up'"
        echo "The $vehicle goes up!"
    ;;
    "down")
        [ -n "$verbose" ] && echo "going 'down'"
        echo "The $vehicle goes down!"
    ;;
    *)
        echo "Not a valid direction!"
        _usage
    ;;
esac
