#!/bin/bash

set -e -o pipefail

script_dir=$(realpath $(dirname "$0"))
filename=$(basename "$0")
command=${filename%.*}

usage_string="${filename%.*} [-v] [-h] <ACTION>..."
_usage () {
    echo "command: $usage_string"
    exit 64
}

while getopts ":vh" opt; do
    case $opt in
        v)
            verbose=-v
            echo "running echo command"
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
Digging is always fun, how's the hole going to end up?

Options:
  -v            Does nothing
  -h            Show this help text

  <ACTION>...   How will you be digging, you can be digging deep or shallow, go
                ahead and dig!
    "
    exit 0
fi

action=$1
shift || _usage
[ -n "$verbose" ] && echo "selected action: $action"

actions_dir="$script_dir/${command}-commands"
case "$action" in
    "deeper" | "shallower")
        [ -n "$verbose" ] && echo "going 'deeper'"
        [ -n "$verbose" ] && echo "with arguments: $verbose $@"
        sub_result=$($actions_dir/$action.sh $verbose "$@")
        echo "digging $sub_result"
    ;;
    *)
        echo "Not a valid action!"
        _usage
    ;;
esac
