#!/bin/bash

set -e -o pipefail

filename=$(basename $0)
command=${filename%.*}
usage_string="$command [-v] [-h] [<DESCRIPTION>]"
_usage () {
    echo "command: $usage_string"
    exit 64
}

while getopts ":vh" opt; do
    case $opt in
        v)
            verbose=-v
            echo "running $command command"
        ;;
        h)
            help=-h
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
Doing something at a slight angle

Options:
  -v            Verbose output, use for debugging.
  -h            Show this help text

  <DESCRIPTION> How's the action at which the angle is taken
    "
    exit 0
fi

[ -n "$1" ] && description="$1" || description="prompt"

echo "at a slight angle with $description action"
