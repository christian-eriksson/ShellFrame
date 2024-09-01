#!/bin/bash

set -e

filename=$(basename $0)
usage_string="${filename%.*} [-v] [-h] [-f <FORMAT>] <INPUT>..."
_usage () {
    echo "command: $usage_string"
    exit 64
}

while getopts ":vf:h" opt; do
    case $opt in
        v)
            verbose=-v
            echo "running echo command"
        ;;
        f)
            formatting=$OPTARG
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
Prints a string with or without formatting.

Options:
  -v            Verbose output, use for debugging.
  -h            Show this help text
  -f <FORMAT>   A formatting string following the same rules as a formatting
                pattern to C printf

  <INPUT>...    One or multiple arguments to be printed. Either as is, if no
                formatting is provided, or as part of the formatting pattern
                given in '-f'
    "
    exit 0
fi

if [ -z "$formatting" ]; then
    [ -n "$verbose" ] && echo "using 'echo'"
    echo "$@"
else
    [ -n "$verbose" ] && echo "using 'printf'"
    printf "$formatting" "$@"
fi
