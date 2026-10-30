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

echo "== end-of-options tests =="
argument_fixture="$tmp_dir/argument-fixture"
mkdir -p "$argument_fixture/commands/probe-commands"
cp "$root/cli.sh" "$argument_fixture/cli.sh"
ln -s "$argument_fixture/cli.sh" "$tmp_dir/arguments-cli"
printf '%s\n' '-e local|test|prod' '-v' > "$argument_fixture/cli-flags.txt"
printf '%s\n' '-b' '-h' > "$argument_fixture/commands/probe-flags.txt"
printf '%s\n' child > "$argument_fixture/commands/probe-completions.txt"
cat > "$argument_fixture/commands/probe.sh" <<'PROBE'
#!/bin/bash
printf 'handler=%s\n' "$(basename "$0")"
printf 'verbose=%s\n' "${SHELLFRAME_VERBOSE:-}"
printf '<%s>\n' "$@"
PROBE
cp "$argument_fixture/commands/probe.sh" "$argument_fixture/commands/probe-commands/child.sh"
chmod +x "$argument_fixture/commands/probe.sh" "$argument_fixture/commands/probe-commands/child.sh"
printf '%s\n' 'PROBE HELP' > "$argument_fixture/commands/probe-help.txt"

assert_arguments() {
    local description="$1" expected="$2"
    shift 2
    local actual result
    actual=$(SHELLFRAME_VERBOSE= SHELLFRAME_ENVIRONMENT= arguments-cli "$@" 2>&1)
    result=$?
    if [[ "$result" -eq 0 && "$actual" = "$expected" ]]; then
        echo "  PASS: $description"
        pass=$((pass + 1))
    else
        echo "  FAIL: $description"
        printf '        expected: %s\n        actual (%s): %s\n' "$expected" "$result" "$actual"
        fail=$((fail + 1))
    fi
}

assert_arguments "literal flags survive the end-of-options marker" \
    $'handler=probe.sh\nverbose=\n<-->\n<-v>\n<-eprod>\n<-e>\n<missing>\n<-h>' \
    probe -- -v -eprod -e missing -h
assert_arguments "literal text does not select a child command" \
    $'handler=probe.sh\nverbose=\n<-->\n<child>' probe -- child
assert_arguments "nested commands preserve empty and multiline literal arguments" \
    $'handler=child.sh\nverbose=\n<-->\n<>\n<hello there>\n<first\nsecond>\n<*>' \
    probe child -- '' 'hello there' $'first\nsecond' '*'
assert_completion "no flags or subcommands after end-of-options" \
    -- arguments-cli probe -- ""
assert_completion "literal option prefix does not complete flags" \
    -- arguments-cli probe -- -

echo "== declared option value tests =="
printf '%s\n' '-d ::VALUE::' '-a ::TEXT::' '-b' '-h' > "$argument_fixture/commands/probe-flags.txt"
printf '%s\n' '-d ::VALUE::' '-a ::TEXT::' '-b' '-h' > "$argument_fixture/commands/probe-child-flags.txt"
printf '%s\n' '-d ::VALUE::' '-a ::TEXT::' '-b' '-h' > "$argument_fixture/commands/probe-commands/child-flags.txt"
assert_arguments "a declared value is not a global verbose flag" \
    $'handler=probe.sh\nverbose=\n<-a>\n<-v>' probe -a -v
assert_arguments "a declared value is not intercepted by help" \
    $'handler=probe.sh\nverbose=\n<-a>\n<-h>' probe -a -h
assert_arguments "a declared value is not an environment option" \
    $'handler=child.sh\nverbose=\n<-a>\n<-eSomething>' probe child -a -eSomething
assert_arguments "a declared value may be the marker itself" \
    $'handler=probe.sh\nverbose=\n<-a>\n<-->\n<-b>' probe -a -- -b
assert_arguments "a boolean does not consume unquoted trailing text" \
    $'handler=child.sh\nverbose=\n<-d>\n<foo>\n<-b>\n<hello>\n<there>\n<peter-parker>' \
    probe child -d foo -b hello there peter-parker
assert_arguments "quoted trailing text retains its argument boundary" \
    $'handler=child.sh\nverbose=\n<-d>\n<foo>\n<-b>\n<hello there peter-parker>' \
    probe child -d foo -b 'hello there peter-parker'
assert_arguments "boolean followed by a value option preserves spaced value" \
    $'handler=child.sh\nverbose=\n<-b>\n<-d>\n<foo  bar>\n<hello>\n<there>' \
    probe child -b -d 'foo  bar' hello there
assert_completion "verbose-shaped value does not consume the verbose option" \
    -d -b -h -e -v child -- arguments-cli probe -a -v ""
assert_completion "marker-shaped value does not end option completion" \
    -d -b -h -e -v child -- arguments-cli probe -a -- ""

echo "== free-text completion tests =="
printf '%s\n' '-d ::VALUE::' '-a @complete:text' '-b' '-h' > "$argument_fixture/commands/probe-commands/child-flags.txt"
printf '%s\n' '@complete:text' > "$argument_fixture/commands/probe-commands/child-completions.txt"
assert_completion "free-text option offers no literal hint" \
    -- arguments-cli probe child -a ""
assert_completion "free-text option offers no flags for a dash prefix" \
    -- arguments-cli probe child -a -
assert_completion "flags resume after a complete text option value" \
    -d -b -h -e -v -- arguments-cli probe child -a 'hello there' ""
assert_completion "positional text offers no literal control marker" \
    -d -a -b -h -e -v -- arguments-cli probe child ""
assert_completion "unquoted trailing words stay in the text input" \
    -- arguments-cli probe child -d foo -b hello there peter-
assert_completion "quoted trailing text stays in the text input" \
    -- arguments-cli probe child -d foo -b 'hello there peter-parker' ""
assert_completion "text does not reenter option completion" \
    -- arguments-cli probe child -b hello -
assert_completion "text does not reenter subcommand completion" \
    -- arguments-cli probe child -b hello child ""
assert_completion "text after end-of-options has no path fallback" \
    -- arguments-cli probe child -- ""

echo "== filesystem flag completion tests =="
path_fixture="$tmp_dir/path-fixture"
path_work="$tmp_dir/path-work"
mkdir -p "$path_fixture/commands" "$path_work/temp/nested" "$path_work/folder with spaces"
cp "$root/cli.sh" "$path_fixture/cli.sh"
ln -s "$path_fixture/cli.sh" "$tmp_dir/path-cli"
printf '%s\n' '-e local|test|prod' '-v' > "$path_fixture/cli-flags.txt"
printf '%s\n' '-t* @complete:path' '-p* ::PATH::' '-s envelope|ingestion|enqueued' '-h' > "$path_fixture/commands/history-download-flags.txt"
touch "$path_work/foo.xml" "$path_work/.hidden"
cd "$path_work"

for prefix in "" . ./ / ./temp/; do
    mapfile -t expected_paths < <(compgen -f -- "$prefix")
    assert_completion "path flag completes filesystem prefix '$prefix'" "${expected_paths[@]}" -- path-cli history download -e local -t "$prefix"
done
assert_completion "path flag keeps a spaced name in one candidate" "folder with spaces" -- path-cli history download -e local -t fold
assert_completion "path flag filters filename prefixes" foo.xml -- path-cli history download -e local -t foo
assert_completion "path flag has no candidates for a missing prefix" -- path-cli history download -e local -t nonexistent
for target in foo ./temp /tmp "folder with spaces"; do
    assert_completion "flags resume after path value '$target'" -p -s -h -v -- path-cli history download -e local -t "$target" ""
done
assert_hint_completion "::PATH:: remains a placeholder after a path value" "::PATH::" -- path-cli history download -e local -t ./temp -p ""
assert_completion "enum flag still works after a path value" envelope ingestion enqueued -- path-cli history download -e local -t ./temp -s ""
assert_completion "positional paths still complete after end-of-options" foo.xml -- path-cli history download -- foo

echo "== quote-aware completion tests =="
assert_line_completion() {
    local description="$1" COMP_LINE="$2" COMP_POINT="$3"
    shift 3
    assert_completion "$description" "$@"
}
quote_line='cli "'
assert_line_completion "opening double quote suppresses subcommands" "$quote_line" "${#quote_line}" -- cli ""
quote_line="cli '"
assert_line_completion "opening single quote suppresses subcommands" "$quote_line" "${#quote_line}" -- cli ""
quote_line='cli "he'
assert_line_completion "quoted subcommand prefix offers no suggestions" "$quote_line" "${#quote_line}" -- cli he
quote_line='cli hello "-'
assert_line_completion "quoted option prefix offers no flags" "$quote_line" "${#quote_line}" -- cli hello -
quote_line='cli hello -u "'
assert_line_completion "quoted text after a boolean offers no suggestions" "$quote_line" "${#quote_line}" -- cli hello -u '"'
for quote in '"' "'"; do
    quote_line="arguments-cli -e $quote"
    assert_line_completion "quoted environment value offers choices with $quote" "$quote_line" "${#quote_line}" local test prod -- arguments-cli -e "$quote"
    quote_line="arguments-cli probe -e ${quote}pro"
    assert_line_completion "quoted nested environment prefix filters choices with $quote" "$quote_line" "${#quote_line}" prod -- arguments-cli probe -e "${quote}pro"
    quote_line="arguments-cli probe child -a $quote"
    assert_line_completion "quoted free-text value still offers no suggestions with $quote" "$quote_line" "${#quote_line}" -- arguments-cli probe child -a "$quote"
done
quote_line='cli -e "'
assert_line_completion "quoted option placeholder retains its hint" "$quote_line" "${#quote_line}" '::ENVIRONMENT::' -- cli -e '"'
quote_line='cli hello world -t "mor'
assert_line_completion "quoted enum prefix completes its option value" "$quote_line" "${#quote_line}" morning -- cli hello world -t '"mor'
quote_line='cli hello world -t "morning"'
assert_line_completion "enum completion uses the prefix up to the cursor" "$quote_line" 26 morning -- cli hello world -t '"morning"'
quote_line='cli hello -g "say \"hello'
assert_line_completion "escaped double quote does not close quoted text" "$quote_line" "${#quote_line}" -- cli hello -g 'say "hello'
quote_line='cli hello -g \" -'
assert_line_completion "escaped quote outside quotes does not suppress flags" "$quote_line" "${#quote_line}" -h -u -e -v -- cli hello -g '\"' -
quote_line='cli hello -g "hello there" '
assert_line_completion "completion resumes after a complete quoted value" "$quote_line" "${#quote_line}" -h -u -e -v world hi all there -- cli hello -g 'hello there' ""
quote_line='path-cli history download -t "fold'
assert_line_completion "double-quoted path completes names with spaces" "$quote_line" "${#quote_line}" 'folder with spaces' -- path-cli history download -t '"fold'
quote_line="path-cli history download -t 'fold"
assert_line_completion "single-quoted path completes names with spaces" "$quote_line" "${#quote_line}" 'folder with spaces' -- path-cli history download -t "'fold"
quote_line='path-cli history download -t "folder with spaces/'
assert_line_completion "repeated completion of a quoted path preserves its prefix" "$quote_line" "${#quote_line}" -- path-cli history download -t '"folder with spaces/'
quote_line='path-cli history download -- "fold'
assert_line_completion "quoted positional paths complete after --" "$quote_line" "${#quote_line}" 'folder with spaces' -- path-cli history download -- '"fold'

if command -v zsh >/dev/null 2>&1; then
    if zsh_output=$(PS1= PS2= RPS1= RPS2= zsh -f -i -s -- "$root" 2>&1 <<'ZSH'
autoload -Uz compinit bashcompinit
compinit -D -i
bashcompinit
unsetopt interactivecomments
CLI_NAME=path-cli source "$1/cli-completion.bash"

for command_prefix in "" hello; do
    COMP_WORDS=(cli)
    expected=hello
    if [[ -n "$command_prefix" ]]; then
        COMP_WORDS+=("$command_prefix")
        expected=world
    fi
    COMP_WORDS+=("")
    words=("${COMP_WORDS[@]}")
    CURRENT=${#words[@]}
    actual=$(compgen -F _cli_completions -- "" 2>&1)
    if [[ "$actual" == *"parse error"* ]] || ! printf '%s\n' "$actual" | grep -qx "$expected"; then
        print -r -- "Expected '$expected' from interactive command discovery, got '$actual'"
        exit 1
    fi
done

_files() { print -r -- paths; }
_bash_complete() { print -r -- flags; }

for path_prefix in "" . ./ / ./temp/n 'folder\ with\ spaces/n'; do
    words=(path-cli history download -e local -t "$path_prefix")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ "$actual" != paths ]]; then
        print -r -- "Expected native paths for '$path_prefix', got '$actual'"
        exit 1
    fi
done

for path_value in foo ./temp /tmp 'folder\ with\ spaces'; do
    words=(path-cli history download -e local -t "$path_value" "")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ "$actual" != flags ]]; then
        print -r -- "Expected flags after '$path_value', got '$actual'"
        exit 1
    fi
done

for flag in -p -s; do
    words=(path-cli history download -e local -t ./temp "$flag" "")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ "$actual" != flags ]]; then
        print -r -- "Expected existing completion for '$flag', got '$actual'"
        exit 1
    fi
done
for text_words in 'hello there' '-v'; do
    COMP_WORDS=(arguments-cli probe child -a "$text_words")
    words=("${COMP_WORDS[@]}")
    CURRENT=${#words[@]}
    actual=$(compgen -F _cli_completions -- "$text_words")
    if [[ -n "$actual" ]]; then
        print -r -- "Expected no free-text suggestions, got '$actual'"
        exit 1
    fi
done
COMP_WORDS=(arguments-cli probe child -b hello there "")
words=("${COMP_WORDS[@]}")
CURRENT=${#words[@]}
actual=$(compgen -F _cli_completions -- "")
if [[ -n "$actual" ]]; then
    print -r -- "Expected no trailing text suggestions, got '$actual'"
    exit 1
fi
COMP_WORDS=(path-cli history download -e local -t ./temp -p "")
words=("${COMP_WORDS[@]}")
CURRENT=${#words[@]}
actual=$(compgen -F _cli_completions -- "")
if [[ "$actual" != "::PATH::" ]]; then
    print -r -- "Expected the literal ::PATH:: placeholder, got '$actual'"
    exit 1
fi
for quote in '"' "'"; do
    BUFFER="cli $quote"
    CURSOR=${#BUFFER}
    words=(cli "$quote")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ -n "$actual" ]]; then
        print -r -- "Expected no suggestions inside $quote, got '$actual'"
        exit 1
    fi
    BUFFER="path-cli history download -t ${quote}fold"
    CURSOR=${#BUFFER}
    words=(path-cli history download -t "${quote}fold")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ "$actual" != paths ]]; then
        print -r -- "Expected native quoted paths, got '$actual'"
        exit 1
    fi
    for value_prefix in '' pro; do
        BUFFER="arguments-cli probe -e ${quote}${value_prefix}"
        CURSOR=${#BUFFER}
        words=(arguments-cli probe -e "${quote}${value_prefix}")
        CURRENT=${#words[@]}
        actual=$(_cli_zsh_completions)
        if [[ "$actual" != flags ]]; then
            print -r -- "Expected quoted environment completion, got '$actual'"
            exit 1
        fi
        COMP_WORDS=("${words[@]}")
        COMP_CWORD=$((CURRENT - 1))
        _cli_line_prefix="${BUFFER:0:$CURSOR}"
        actual=$(compgen -F _cli_completions -- "${words[CURRENT]}")
        unset _cli_line_prefix
        expected=$'local\ntest\nprod'
        if [[ "$actual" != "$expected" ]]; then
            print -r -- "Expected environment candidates for native matching '$expected', got '$actual'"
            exit 1
        fi
    done
done
typeset -A compstate
for quote in '"' "'"; do
    compstate[quote]="$quote"
    BUFFER='cli '
    CURSOR=${#BUFFER}
    words=(cli "$quote")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ -n "$actual" ]]; then
        print -r -- "Expected native quote state to suppress suggestions, got '$actual'"
        exit 1
    fi
    BUFFER='arguments-cli probe -e pro'
    CURSOR=${#BUFFER}
    words=(arguments-cli probe -e "${quote}pro")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ "$actual" != flags ]]; then
        print -r -- "Expected option values with native quote state, got '$actual'"
        exit 1
    fi
    BUFFER='path-cli history download -t fold'
    CURSOR=${#BUFFER}
    words=(path-cli history download -t "${quote}fold")
    CURRENT=${#words[@]}
    actual=$(_cli_zsh_completions)
    if [[ "$actual" != paths ]]; then
        print -r -- "Expected paths with native quote state, got '$actual'"
        exit 1
    fi
done
ZSH
    ); then
        echo "  PASS: interactive zsh command discovery and native path dispatch"
        pass=$((pass + 1))
    else
        echo "  FAIL: interactive zsh command discovery and native path dispatch"
        echo "        $zsh_output"
        fail=$((fail + 1))
    fi
else
    echo "  SKIP: interactive zsh completion (zsh is not installed)"
fi
cd "$root"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
