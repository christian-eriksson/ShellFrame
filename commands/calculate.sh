#!/bin/bash

set -e -o pipefail

filename=$(basename $0)
usage_string="${filename%.*} [-v] [-h] <OPERATION> <TERM>..."
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
Preforms the math operation with the provided terms.

Options:
  -v            Verbose output, use for debugging.
  -h            Show this help text

  <OPERATION>   The operation to perform, these are the supported operations:
                'add', 'subtract'
  <TERM>...     The terms to perform the operation on, minimum 2 terms need to
                be provided.\
    "
    exit 0
fi

[ -n "$1" ] && operation_name="$1"
shift || (echo "you need to provide an operation" && _usage)

terms=("$@")

if [ "${#terms[@]}" -lt "2" ]; then
    echo "you need to provide at least two terms" && _usage
fi

case "$operation_name" in
    "add")
        [ -n "$verbose" ] && echo "performing add operation"
        sum=0
        for term in "${terms[@]}"; do
            sum=$(($sum + $term))
        done
        echo $sum
    ;;
    "subtract")
        [ -n "$verbose" ] && echo "performing subtract operation"
        sum="${terms[0]}"
        i=1
        while [ $i -lt ${#terms[@]} ]; do
            sum=$(($sum - ${terms[$i]}))
            i=$(($i + 1))
        done
        echo $sum
    ;;
    *)
        echo "Not a valid operation!"
        _usage
    ;;
esac
