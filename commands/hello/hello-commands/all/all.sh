#!/bin/bash

set -e

filename=$(basename $0)
usage_string="hello ${filename%.*} [-h] -p <PERIOD> [day|night]"
_usage () {
    echo "command: $usage_string"
    exit 64
}

# -v is reserved by cli.sh (see README.md#the--v-flag) and never reaches this
# script's own argv - read $SHELLFRAME_VERBOSE directly instead of parsing it.
while getopts ":hp:" opt; do
    case $opt in
        h)
            help=-h
        ;;
        p)
            period=$OPTARG
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
Lives in commands/hello/hello-commands/all/all.sh (a nested single-command
directory, one level deeper than the base-command case) and itself has a
further nested-inside sub-commands directory
(commands/hello/hello-commands/all/all-commands/), proving the chain works
2 levels deep - see 'hello all day'/'hello all night' (those bypass this
script entirely - they're separate executables, see day.sh/night.sh).

Also demonstrates a required flag with its own enumerated completion hint
(-p, see all-flags.txt) at this nesting level.

Commands:
  day    Greet the whole day
  night  Greet the whole night

Options:
  -h            Show this help text
  -p <PERIOD>   (required) sunrise or sunset"
    exit 0
fi

case "$period" in
    sunrise | sunset) ;;
    "")
        echo "missing period! (-p sunrise|sunset)" >&2
        _usage
    ;;
    *)
        echo "Invalid -p value: '$period' (want sunrise|sunset)" >&2
        _usage
    ;;
esac

echo "Hello, all! ($period)"
