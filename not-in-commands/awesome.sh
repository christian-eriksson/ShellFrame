#!/bin/bash

set -e

filename=$(basename $0)
usage_string="${filename%.*} [-v] [-h]"
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
    filename=$(basename $0)
    echo \
    "Usage: $usage_string

Description:
Simply prints "AWESOME!"

Options:
  -v        Verbose output, use for debugging.
  -h        Show this help text

  <LEVEL>   the amount of AWESOME!
    "
    exit 0
fi


case "$1" in
    "most" | "max" | "mega")
        level="$(echo "$1" | tr "[a-z]" "[A-Z]") "
    ;;
    *)
        [ -n "$1" ] && echo "NOT ENOUGH AWESOME!" && exit 1
    ;;
esac

echo "${level}AWESOME!"
