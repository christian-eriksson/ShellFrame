#!/bin/bash

set -e

filename=$(basename $0)
usage_string="hello ${filename%.*} [-h] [-c]"
_usage () {
    echo "command: $usage_string"
    exit 64
}

# -v is reserved by cli.sh (see README.md#the--v-flag) and never reaches this
# script's own argv - read $SHELLFRAME_VERBOSE directly instead of parsing it.
while getopts ":hc" opt; do
    case $opt in
        h)
            help=-h
        ;;
        c)
            cheerful=1
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
Lives in commands/hello/hello-commands/hi/hi.sh - discovery method B
(nested single-command directory used for a sub-command, one level
deeper than the base-command case). Also demonstrates a flags file at
this nesting level (hi-flags.txt) with a no-input flag (-c).

Options:
  -h            Show this help text
  -c            Cheerful mode - adds extra exclamation marks (no input)"
    exit 0
fi

if [ -n "$cheerful" ]; then
    echo "Hi!!!"
else
    echo "Hi!"
fi
