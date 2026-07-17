#!/bin/bash
# Plain-bash regression test suite for ShellFrame's own demo commands
# (../commands/) - execution and tab completion. No external test
# framework; run directly:
#
#   .shellframe/test/run-tests.sh
#
# Exits 0 if every assertion passes, 1 otherwise.

set -o pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

tmp_dir=$(mktemp -d)
ln -s "$root/cli.sh" "$tmp_dir/cli"
export PATH="$tmp_dir:$PATH"
export CLI_NAME=cli
source "$root/cli-completion.bash"

base_dir_backup=""
if [ -f "$root/.base-dir" ]; then
    base_dir_backup="$tmp_dir/.base-dir.bak"
    mv "$root/.base-dir" "$base_dir_backup"
fi

cleanup() {
    [ -n "$base_dir_backup" ] && mv "$base_dir_backup" "$root/.base-dir"
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

pass=0
fail=0

# assert_output <description> <expected_exit_code> <grep_-E_pattern_or_''> -- <cli args...>
assert_output() {
    local desc="$1" expected_exit="$2" pattern="$3"
    shift 3
    [ "${1:-}" = "--" ] && shift
    local output actual_exit
    output=$(cli "$@" 2>&1)
    actual_exit=$?
    if [ "$actual_exit" != "$expected_exit" ]; then
        echo "  FAIL: $desc"
        echo "        command:       cli $*"
        echo "        expected exit: $expected_exit"
        echo "        actual exit:   $actual_exit"
        echo "        actual output: $output"
        echo
        fail=$((fail + 1))
        return
    fi
    if [ -n "$pattern" ] && ! grep -qE -- "$pattern" <<<"$output"; then
        echo "  FAIL: $desc"
        echo "        command: cli $*"
        echo "        expected pattern to match output: \`$pattern\`"
        echo "        actual output: $output"
        echo
        fail=$((fail + 1))
        return
    fi
    echo "  PASS: $desc"
    pass=$((pass + 1))
}

# assert_completion <description> <expected words...> -- <COMP_WORDS...>
# (last COMP_WORD should be "" for a trailing-space completion, as usual)
assert_completion() {
    local desc="$1"
    shift
    local expected=()
    while [ "$1" != "--" ]; do
        expected+=("$1")
        shift
    done
    shift
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    COMPREPLY=()
    _cli_completions
    local actual want
    actual=$(printf '%s\n' "${COMPREPLY[@]}" | sed 's/[[:space:]]*$//' | grep -v '^$' | sort -u)
    want=$(printf '%s\n' "${expected[@]}" | sed 's/[[:space:]]*$//' | grep -v '^$' | sort -u)
    if [ "$actual" != "$want" ]; then
        echo "  FAIL: $desc"
        echo "        expected words: ${expected[*]}"
        echo "        actual words:   ${COMPREPLY[*]}"
        echo
        fail=$((fail + 1))
        return
    fi
    echo "  PASS: $desc"
    pass=$((pass + 1))
}

# assert_hint_completion <description> <expected_hint> -- <COMP_WORDS...>
# A hint value (e.g. ::NAME::) is displayed, not auto-filled, by returning it
# alongside a blank companion entry - with 2+ COMPREPLY candidates bash just
# lists them instead of appending one + a trailing space. Verifies COMPREPLY
# is exactly [<expected_hint>, ""], unlike assert_completion which discards
# blank entries to compare real word lists.
assert_hint_completion() {
    local desc="$1" expected_hint="$2"
    shift 2
    [ "${1:-}" = "--" ] && shift
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    COMPREPLY=()
    _cli_completions
    if [ "${#COMPREPLY[@]}" -ne 2 ] || [ "${COMPREPLY[0]}" != "$expected_hint" ] || [ -n "${COMPREPLY[1]}" ]; then
        echo "  FAIL: $desc"
        echo "        expected exactly 2 entries: [\"$expected_hint\", \"\"]"
        echo "        actual entries:             [${COMPREPLY[*]}]"
        echo
        fail=$((fail + 1))
        return
    fi
    echo "  PASS: $desc"
    pass=$((pass + 1))
}

echo "== execution tests =="
assert_output "direction -n car left works"           0  "goes to the left"     -- direction -n car left
assert_output "direction -n car right works"          0  "goes to the right"    -- direction -n car right
assert_output "direction without -n fails"            64 "missing vehicle name" -- direction left
assert_output "direction -h documents -n"             0  "n <NAME>"             -- direction -h
assert_output "direction -n car left hard runs"       0  ""                     -- direction -n car left hard
assert_output "direction -n car left slight runs"     0  ""                     -- direction -n car left slight
assert_output "automatic: -v not set reads empty"     0  "verbose: ''"          -- automatic
assert_output "automatic -v reads SHELLFRAME_VERBOSE" 0  "verbose: '1'"         -- automatic -v
assert_output "group foo -v reads SHELLFRAME_VERBOSE" 0  "verbose: '1'"         -- group foo -v
assert_output "group bar runs"                        0  "Hello from"          -- group bar
assert_output "group sub_group baz runs"              0  "Hello from"          -- group sub_group baz
# These two check the ACTUAL resolved script path, not just the "Hello from"
# text shared by every demo script under commands/automatic-commands/ - a
# dispatch bug in _find_command's sub-command walk can silently fall back to
# the wrong (parent) executable while still printing a generic "Hello from"
# line, which would make a plain substring match pass even though the wrong
# script ran. See cli.sh's _find_command: a command that has BOTH its own
# executable and a further sub-commands directory (sub-automatic.sh +
# sub-automatic-commands/) used to unconditionally descend one more level
# looking for the next token even when none was left, fail to find anything,
# and fall back all the way to the top-level command (automatic.sh) instead
# of the correctly-resolved sub-automatic.sh.
assert_output "automatic sub-automatic runs"           0  "^Hello from:.*automatic-commands/sub-automatic\.sh"          -- automatic sub-automatic
assert_output "automatic sub-automatic sub-sub-automatic runs" 0 "^Hello from:.*sub-automatic-commands/sub-sub-automatic\.sh" -- automatic sub-automatic sub-sub-automatic
assert_output "dig deeper runs (no runtime -e enforcement)" 0 "" -- dig deeper
assert_output "dig shallower runs"                    0  ""                     -- dig shallower

# hello (commands/hello/hello.sh) - nested single-command directory + a mix
# of custom flags (no-input, placeholder hint, enumerated hint, required).
assert_output "hello <NAME> greets"                   0  "Hello, Chris!"        -- hello Chris
assert_output "hello -u uppercases (no-input flag)"    0  "HELLO, CHRIS!"        -- hello -u Chris
assert_output "hello -g overrides greeting (placeholder-hint flag)" 0 "Hey, Chris!" -- hello -g Hey Chris
assert_output "hello there is handled inline (no executable)" 0 "handled inline" -- hello there
assert_output "hello world runs (flat executable sub-command)" 0 "Hello, world!" -- hello world
assert_output "hello world -t morning (enumerated-hint flag)" 0 "Good morning, world!" -- hello world -t morning
assert_output "hello world -t bogus rejects invalid enum value" 64 "Invalid -t value" -- hello world -t bogus
assert_output "hello hi runs (nested single-command sub-command)" 0 "Hi!"    -- hello hi
assert_output "hello hi -c is cheerful (no-input flag, own nesting level)" 0 "Hi!!!" -- hello hi -c
assert_output "hello all -p sunrise runs (required + enumerated-hint flag)" 0 "Hello, all! \(sunrise\)" -- hello all -p sunrise
# Regression test for a dispatch bug: a command that has BOTH its own
# executable and a further sub-commands directory (all.sh + all-commands/)
# used to over-descend on a bare invocation with no more tokens, fail to
# find anything, and silently fall back to the TOP-level command (hello.sh)
# instead of the correctly-resolved intermediate command (all.sh) - masked
# previously because both scripts' demo output happened to look similar.
# 'hello all' bare must reach all.sh (and fail its own required -p check),
# never fall back to hello.sh (which would otherwise treat 'all' as <NAME>
# and print 'Hello, all!' with exit 0).
assert_output "hello all (bare) reaches all.sh, not hello.sh's NAME fallback" 64 "missing period" -- hello all
assert_output "hello all day bypasses all.sh (separate leaf executable)" 0 "Hello, all day!" -- hello all day
assert_output "hello all night bypasses all.sh (separate leaf executable)" 0 "Hello, all night!" -- hello all night

echo "== completion tests =="
assert_completion "dig offers -h/-e/-v plus deeper/shallower" -h -e -v deeper shallower -- cli dig ""
assert_completion "dig -e offers the global ::ENVIRONMENT:: hint" "::ENVIRONMENT::" -- cli dig -e ""
assert_completion "ls -e offers its own custom hint, not the global enum" small medium large -- cli ls -e ""
assert_completion "calculate offers merged -e/-v plus add/subtract" -h -e -v add subtract -- cli calculate ""
assert_completion "direction offers its own -n plus the global -e/-v" -h -e -v -n left right up down -- cli direction ""
assert_hint_completion "dig -e shows the ::ENVIRONMENT:: hint without auto-filling it (blank companion entry)" "::ENVIRONMENT::" -- cli dig -e ""
assert_hint_completion "direction -n shows its own ::VEHICLE_NAME:: hint without auto-filling it" "::VEHICLE_NAME::" -- cli direction -n ""
assert_completion "hello offers world/hi/all/there plus -h/-u/-g/-e/-v" -h -u -g -e -v world hi all there -- cli hello ""
assert_completion "hello all offers its own -p (required) plus -h/-e/-v, and day/night" -h -p -e -v day night -- cli hello all ""
assert_hint_completion "hello -g shows the ::GREETING:: placeholder hint" "::GREETING::" -- cli hello -g ""
assert_completion "hello world -t offers the enumerated time-of-day values" morning afternoon evening -- cli hello world -t ""
assert_completion "hello all -p offers the enumerated sunrise/sunset values" sunrise sunset -- cli hello all -p ""

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
