#!/bin/bash

set -e -o pipefail

script_dir=$(realpath $(dirname "$0"))
filename=$(basename $0)
command=${filename%.*}
usage_string="$command [-v] [-h] [-s <SPEED>] [<CHARACTER>]"
_usage () {
    echo "command: $usage_string"
    exit 64
}

speed="10 km/h"
while getopts ":vhs:" opt; do
    case $opt in
        v)
            verbose=-v
            echo "running $command command"
        ;;
        h)
            help=-h
        ;;
        s)
            speed=$OPTARG
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

if [ -n "$help" ]; then
    filename=$(basename $0)
    echo \
    "Usage: $usage_string

Description:
Taking a left turn

Options:
  -v        Verbose output, use for debugging.
  -h        Show this help text

  <SPEED>   The speed at which to turn left, defaults to 10 km/h.\
    "
    exit 0
fi

character="$1"
sub_command="$script_dir/${command}-commands/$character"
if [ -n "$character" ]; then
    if [ -f "$sub_command" ] && [ -x "$sub_command" ]; then
        sub_result=$($sub_command "$@")
        echo "the left (at a speed of $speed) $sub_result!"
    else
        echo "the left (at a speed of $speed)!"
    fi
else
    echo "the left (at a speed of $speed)!"
fi
