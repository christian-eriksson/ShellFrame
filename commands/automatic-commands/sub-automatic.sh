#!/bin/bash

echo "Hello from: $(realpath $0) $@"

echo "1: '$1' | 2: '$2' | 3: '$3'"

while getopts ":h" opt; do
    case $opt in
    h)
        help=-h
        ;;
    \?)
        echo "Invalid option: '-$OPTARG'" >&2
        exit 64
        ;;
    :)
        echo "Option '-$OPTARG' requires an argument." >&2
        exit 64
        ;;
    esac
done

echo "help: '$help' | verbose: '$SHELLFRAME_VERBOSE' | environment: '$SHELLFRAME_ENVIRONMENT'"
