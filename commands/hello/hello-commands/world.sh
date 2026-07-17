#!/bin/bash

set -e

filename=$(basename $0)
usage_string="hello ${filename%.*} [-h] [-t <TIME>]"
_usage () {
    echo "command: $usage_string"
    exit 64
}

# -v is reserved by cli.sh (see README.md#the--v-flag) and never reaches this
# script's own argv - read $SHELLFRAME_VERBOSE directly instead of parsing it.
while getopts ":ht:" opt; do
    case $opt in
        h)
            help=-h
        ;;
        t)
            time_of_day=$OPTARG
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
A real, separate executable in commands/hello/hello-commands/world.sh -
discovery method A (flat executable in a nested-inside sub-commands
directory). Also demonstrates a flag with an enumerated completion hint
(-t, see world-flags.txt).

Options:
  -h            Show this help text
  -t <TIME>     Time of day to greet for: morning, afternoon or evening"
    exit 0
fi

case "$time_of_day" in
    morning) echo "Good morning, world!" ;;
    afternoon) echo "Good afternoon, world!" ;;
    evening) echo "Good evening, world!" ;;
    "") echo "Hello, world!" ;;
    *)
        echo "Invalid -t value: '$time_of_day' (want morning|afternoon|evening)" >&2
        exit 64
    ;;
esac
