#!/bin/bash

set -e -o pipefail

script_path=$(readlink "$0") || script_path="$0"
script_dir=$(realpath $(dirname "$script_path"))
script_file=$(basename $script_path)
script_name=${CLI_NAME:-${script_file%.*}}

# base_dir is where commands/, *-usage.txt, *-help.txt and .env.* are looked
# up. Defaults to script_dir but can be redirected to an external directory
# (e.g. when this repo is used as a git submodule) via a '.base-dir' file
# placed next to this script, containing a single path (absolute, or relative
# to script_dir).
base_dir="$script_dir"
if [ -f "$script_dir/.base-dir" ]; then
    base_dir=$(cat "$script_dir/.base-dir")
    [ "${base_dir:0:1}" != "/" ] && base_dir="$script_dir/$base_dir"
    base_dir=$(realpath "$base_dir")
fi

usage_file="$base_dir/$script_name-usage.txt"
if [ -f "$usage_file" ]; then
    usage_string=$(sed "s%{CLI_NAME}%$(basename $0)%" $usage_file)
else
    usage_string="Usage: $(basename $0) [-h] [-e <ENVIRONMENT>] [-v] <COMMAND> [<OPTIONS>] [<INPUT>]"
fi

_usage() {
    echo "$usage_string"
    exit 64
}

# -e/<ENVIRONMENT> and -v are CLI-wide and, unlike -h, allowed anywhere in
# the argument list - not just before the command name - so they can be
# combined freely with command-specific flags, e.g. 'cli command -e dev -v'
# works the same as `cli -e dev -v command`. We extract them first, then let
# getopts handle -h (still leading-position only, per each command's own -h
# contract).
_raw_args=("$@")
set --
_skip_next=false
for _arg in "${_raw_args[@]}"; do
    if $_skip_next; then
        environment="$_arg"
        _skip_next=false
        continue
    fi
    case "$_arg" in
    -e)
        _skip_next=true
        ;;
    -e?*)
        environment="${_arg#-e}"
        ;;
    -v)
        verbose=1
        ;;
    *)
        set -- "$@" "$_arg"
        ;;
    esac
done
if $_skip_next; then
    echo "Option '-e' requires an argument." >&2
    _usage
fi
unset _raw_args _skip_next _arg

while getopts ":h" opt; do
    case $opt in
    h)
        help=-h
        ;;
    \?)
        echo "Invalid option: '-$OPTARG'" >&2
        _usage
        ;;
    :)
        echo "Option '-$OPTARG' requires an argument." >&2
        _usage
        ;;
    esac
done

shift $((OPTIND - 1)) # remove options from positional parameters

# A command may either live directly in commands/ (flat, e.g. commands/foo.sh)
# or, to keep commands/ tidy, in its own subdirectory named after it
# (commands/foo/foo.sh) - NOT to be confused with commands/foo-commands/,
# which holds separate executables for foo's own sub-commands. The nested
# form is auto-detected (no config needed): it only kicks in when
# commands/<name>/<name>.<ext> actually exists, so existing flat setups are
# completely unaffected. See README.md#nested-command-directories.
command_executables="$(find -L $base_dir/commands/ -maxdepth 1 -perm -111 -not -type d -print
find -L $base_dir/commands/ -maxdepth 1 -type d -not -name '*-commands' -print | while read -r dir; do
    name=$(basename "$dir")
    find -L "$dir/" -maxdepth 1 -iname "${name}.*" -perm -111 -not -type d -print
done)"

if [ -n "$help" ]; then
    echo $usage_string
    help_file="$base_dir/$script_name-help.txt"
    if [ -f "$help_file" ]; then
        printf -- "\n"
        cat "$help_file"
    fi
    echo -e "\nCommands:\n"
    echo "$command_executables" | while read -r file; do
        filename=$(basename $file)
        printf -- "- %s\n" "${filename%.*}"
    done
    find $base_dir/commands/ -ipath .*-help.txt | while read -r file; do
        filename=$(basename $file)
        printf -- "- %s\n" "${filename%-help.txt}"
    done

    echo "$command_executables" | while read -r file; do
        [ ! -x "$file" ] && continue
        filename=$(basename $file)
        command=${filename%.*}
        echo -e "\n# ${command^^}\n"
        directory=$(dirname $file)
        help_file="${directory}/${command}-help.txt"
        if [ -f "$help_file" ]; then
            cat $help_file
            printf -- "\n"
        else
            "$file" -h
        fi
    done

    find $base_dir/commands/ -ipath "*-help.txt" | while read -r file; do
        filename=$(basename $file)
        command=${filename%-help.txt}
        command_file=$(find $base_dir/commands/ -iname ${command}.*)
        if [ -z "${command_file}" ]; then
            echo -e "\n# ${command^^}\n"
            cat $file
        fi
    done
    printf -- "\n"
    exit 0
fi

command=$1
shift || (echo "ERROR: no command provided!" && _usage)

_find_executable() {
    local dir="$1" name="$2"
    # Nested single-command directory (commands/<name>/<name>.<ext>) takes
    # precedence over the flat form when both would somehow exist - see the
    # comment above command_executables.
    if [ -d "$dir/$name" ]; then
        local nested_match
        nested_match=$(find -L "$dir/$name/" -maxdepth 1 -iname "${name}.*" -perm -111 -not -type d -print | grep "${name}\.[[:alnum:]]\+$") || true
        if [ -n "$nested_match" ]; then
            echo "$nested_match"
            return 0
        fi
    fi
    find -L "$dir/" -maxdepth 1 -iname "${name}.*" -perm -111 -not -type d -print |
        grep "${name}\.[[:alnum:]]\+$"
}

_find_command() {
    [ -n "$verbose" ] && echo "searching for command: '$command'"
    arguments=("$@")
    sub_commands=()
    for arg in "${arguments[@]}"; do
        [ -z "$arg" ] && continue
        case "$arg" in
        -*)
            break
            ;;
        *)
            sub_commands+=($arg)
            ;;
        esac
    done
    sub_command_path="$base_dir/commands"
    sub_command=$command
    idx=0
    # A command's own sub-commands directory may live nested inside its own
    # single-command directory ($sub_command_path/$sub_command/$sub_command-
    # commands, e.g. commands/hello/hello-commands/) or, as before, as a
    # sibling ($sub_command_path/$sub_command-commands, e.g.
    # commands/hello-commands/) - the nested form is checked first so a
    # command using the nested single-command directory convention can keep
    # its sub-commands together with it instead of spilling a sibling
    # directory into commands/.
    #
    # Only descend when there's actually another token left to look up at
    # the next level - otherwise a command that has BOTH its own executable
    # and a further sub-commands directory (e.g. commands/automatic-
    # commands/sub-automatic.sh + commands/automatic-commands/sub-automatic-
    # commands/) would always over-descend on a bare invocation (e.g.
    # 'automatic sub-automatic'), fail to find anything for the missing next
    # token, and fall back all the way to the top-level command - silently
    # skipping the correctly-resolved intermediate command ('sub-automatic')
    # entirely.
    while [ "$idx" -lt "${#sub_commands[@]}" ]; do
        if [ -d "$sub_command_path/$sub_command/$sub_command-commands" ]; then
            sub_command_path="$sub_command_path/$sub_command/$sub_command-commands"
        elif [ -d "$sub_command_path/$sub_command-commands" ]; then
            sub_command_path="$sub_command_path/$sub_command-commands"
        else
            break
        fi
        sub_command="${sub_commands[$idx]}"
        [ -n "$verbose" ] && echo "searching for sub command '$sub_command' in: '$sub_command_path'"
        idx=$((idx + 1))
    done

    command_executable=$(_find_executable "$sub_command_path" "$sub_command") || true
    if [ -z "$command_executable" ]; then
        [ -n "$verbose" ] && echo "WARNING: no command executable found for sub command '$sub_command' at '$sub_command_path'!" || true
        command_executable=$(_find_executable "$base_dir/commands" "$command") || true
        # Falling back to the base command itself (rather than a sub-command
        # found via the loop above) means none of $sub_commands were
        # actually consumed as a path to a sub-command executable - e.g. a
        # command whose own script handles some positional values itself
        # (see commands/hello/hello-completions.txt's 'there'). Reset idx so
        # the "unset arguments" loop below doesn't strip arguments that were
        # never actually resolved to a sub-command directory.
        [ -n "$command_executable" ] && idx=0
    fi
    if [ -z "$command_executable" ]; then
        if [ "$idx" -gt "0" ]; then
            echo "ERROR: no command executable found for sub command '$sub_command' at '$sub_command_path'!"
        fi
        echo "ERROR: no command executable found for command '$command' at '$command_path'!"
        exit 1
    fi
    while [ "$idx" -gt "0" ] && [ -n "$sub_command" ]; do
        idx=$((idx - 1))
        unset arguments[$idx]
    done
    command_path=$command_executable

    [ -n "$verbose" ] && echo "found command path: '$command_path'" || true
}

_find_command "$@" || _usage

_run_command() {
    set -a
    if [ -n "${environment}" ]; then
        if ! . $base_dir/.env.$environment 2>/dev/null; then
            echo "ERROR: could not load config: '$base_dir/.env.$environment'!!!"
            exit 64
        fi
        SHELLFRAME_ENVIRONMENT="$environment"
    fi
    [ -n "$verbose" ] && SHELLFRAME_VERBOSE=1
    set +a
    arguments=("$@")

    for arg in "${arguments[@]}"; do
        if [ "$arg" == "-h" ]; then
            help=$arg
        fi
    done

    if [ -n "$help" ]; then
        command_file=$(basename $command_path)
        command=${command_file%.*}
        command_dir=$(dirname $command_path)
        help_file="${command_dir}/${command}-help.txt"
        if [ -f "$help_file" ]; then
            cat $help_file
            printf -- "\n"
        else
            "$command_path" "${arguments[@]}"
        fi
    else
        if [ -d "$command_path" ]; then
            echo "ERROR: no sub command in path '$command_path'!" && exit 64
        fi
        "$command_path" "${arguments[@]}"
    fi
}

if [ -x "$command_path" ] || ([ -L "$command_path" ] && [ -x "$(readlink $command_path)" ]); then
    [ -n "$verbose" ] && echo "running command: $command_path"
    [ -n "$verbose" ] && echo "with arguments: ${arguments[@]}"
    (_run_command "${arguments[@]}") || ([ "$?" -eq 64 ] && _usage)
else
    [ -n "$verbose" ] && echo "command file '$command_path' does not exist or is not executable"
    echo "ERROR: '$command' is not a command"
    _usage
fi
