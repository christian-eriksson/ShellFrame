#!/bin/bash

set -e

filename=$(basename $0)
usage_string="hello all ${filename%.*} [-v] [-h]"
_usage () {
    echo "command: $usage_string"
    exit 64
}

while getopts ":vh" opt; do
    case $opt in
        v)
            verbose=-v
            echo "running ${filename%.*} command"
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
    echo \
    "Usage: $usage_string

Description:
2 levels deep: commands/hello/hello-commands/all/all-commands/night.sh.

Options:
  -v            Verbose output, use for debugging.
  -h            Show this help text"
    exit 0
fi

echo "Hello, all night!"
