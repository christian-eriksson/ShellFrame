#!/bin/bash

set -e

filename=$(basename $0)
usage_string="${filename%.*} [-h] [-u] [-g <GREETING>] <NAME>"
_usage () {
    echo "command: $usage_string"
    exit 64
}

# -v is reserved by cli.sh (see README.md#the--v-flag) and never reaches this
# script's own argv - read $SHELLFRAME_VERBOSE directly instead of parsing it.
while getopts ":hug:" opt; do
    case $opt in
        h)
            help=-h
        ;;
        u)
            upper=1
        ;;
        g)
            greeting=$OPTARG
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
Greets <NAME>. Lives in commands/hello/hello.sh instead of a flat
commands/hello.sh, to demonstrate the nested command directory convention
- see README.md#nested-command-directories.

Also has sub-commands demonstrating every tab-completion discovery method
- see commands/hello/hello-commands/ and hello-completions.txt:
  world       Real executable, hello-commands/world.sh
  hi          Nested single-command dir, hello-commands/hi/hi.sh
  all         Nested single-command dir with its own further sub-commands,
              hello-commands/all/ (see 'hello all -h')
  there       No executable at all - just listed in hello-completions.txt
              and handled inline, right here in hello.sh

Also demonstrates a mix of custom flags in its own flags file
(hello-flags.txt): a no-input flag (-u) and a flag with a placeholder
completion hint (-g ::GREETING::).

Options:
  -h              Show this help text
  -u              Uppercase the greeting (no input)
  -g <GREETING>   Word to greet with instead of 'Hello' (e.g. 'Hi', 'Hey')

  <NAME>          Who to greet"
    exit 0
fi

if [ $# -eq 0 ]; then
    _usage
fi

# 'there' has no executable of its own - it only exists in
# hello-completions.txt for tab completion, and is handled directly here.
if [ "$1" = "there" ]; then
    echo "Hello there! (handled inline by hello.sh, not a separate executable)"
    exit 0
fi

message="${greeting:-Hello}, $1!"
[ -n "$upper" ] && message=$(echo "$message" | tr '[:lower:]' '[:upper:]')
echo "$message"
