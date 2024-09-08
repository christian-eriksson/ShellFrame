#!/bin/bash

set -e -o pipefail

script_dir=$(realpath $(dirname "$0"))
filename=$(basename $0)

usage_string="${filename%.*} [-v] [-h] [deeper|shallower...]"
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
You can dig a deep hole with this.

Options:
  -v                    Verbose logging during execution
  -h                    Show this help text

  deeper|shallower...   Chain one or multiple 'deeper' or 'shallower' together
                        to determine the final dig!
    "
    exit 0
fi

action=$1
shift || true
[ -n "$verbose" ] && echo "selected action: '$action'"

[ -z "$action" ] && echo "deeper" && exit 0

case "$action" in
    "deeper" | "shallower")
        [ -n "$verbose" ] && echo "going '$action'"
        [ -n "$verbose" ] && echo "with arguments: $verbose $@"
        sub_result=$($script_dir/$action.sh $verbose "$@")
        echo "deeper $sub_result"
    ;;
    *)
        echo "Not a valid action!"
        _usage
    ;;
esac

