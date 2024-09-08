#!/bin/bash

set -e -o pipefail

filename=$(basename $0)
command=${filename%.*}
usage_string="$command [-v] [-h]"
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
Doing something at a hard angle

Options:
  -v            Verbose output, use for debugging.
  -h            Show this help text
    "
    exit 0
fi

echo "at a hard angle"
