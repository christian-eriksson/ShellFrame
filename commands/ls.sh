#!/bin/bash

set -e

filename=$(basename $0)
usage_string="${filename%.*} [-v] [-h] [-a] [-l] [<PATH>...]"
_usage () {
    echo "command: $usage_string"
    exit 64
}

while getopts ":valh" opt; do
    case $opt in
        v)
            verbose=-v
            echo "running ls command"
        ;;
        a)
            all=-a
        ;;
        l)
            list=-l
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
  -v        Verbose output, use for debugging.
  -h        Show this help text
  -a        Show all the content of the directory including
  -l        List the content with sizes and update dates, instead of showing
            only the name of the directory content or file.

  <PATH>... One or multiple paths to file/-s or directory/-ies to be listed. If
            no path is provided it will list the current directory.\
    "
    exit 0
fi

if [ -n "$verbose" ]; then
    [ -n "$all" ] && echo "showing all files"
    [ -n "$list" ] && echo "listing files with size"
fi

ls -h $all $list $@
