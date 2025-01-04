#!/bin/bash

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

if [ -n "${help}" ]; then
    echo "Usage: automatic-other [-h] [-v]

Description:
Prints hello and from what path it is running with what input"
    exit 0
fi

echo "Hello from: $(realpath $0) $@"
