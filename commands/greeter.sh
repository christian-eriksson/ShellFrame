#!/bin/bash

set -e

filename=$(basename $0)
usage_string="${filename%.*} [-v] [-h] [<NAME>]"
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
Prints a greeing to the caller or the world then exits. You can configure a
default greeting with the 'DEFAULT_GREETING' environment variable.

Options:
  -v        Verbose output, use for debugging.
  -h        Show this help text

  <NAME>    The name of the person to greet, if omitted the greeter will print
            the default greeting. You can configure the default greeting in
            'DEFAULT_GREETING'.\
    "
    exit 0
fi

[ -n "$1" ] && name="$1"

if [ -n "$name" ]; then
    [ -n "$verbose" ] && echo "greeing name: $name"
    echo "Hello $name!"
else
    [ -n "$verbose" ] && echo "using default greeting"
    [ -z "$DEFAULT_GREETING" ] && greeting="Hello Stranger!" || greeting="$DEFAULT_GREETING"
    echo $greeting
fi
