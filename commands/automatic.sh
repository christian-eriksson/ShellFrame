#!/bin/bash

echo "Hello from: $(realpath $0) $@"

echo "1: '$1' | 2: '$2' | 3: '$3'"

while getopts ":e:vh" opt; do
    case $opt in
    e)
        environment=$OPTARG
        ;;
    v)
        verbose=-v
        ;;
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

echo "help: '$help' | verbose: '$verbose' | environment: '$environment'"
