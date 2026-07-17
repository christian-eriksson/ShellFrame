#!/bin/bash
# Source this file to manually exercise ShellFrame's own demo commands (in
# ../commands/) through a real 'cli' with working tab completion - entirely
# scoped to the current shell session. Nothing is installed: no PATH/rc
# file changes survive past this shell, and '.base-dir' (which normally
# redirects this submodule to an external repo's commands/) is swapped
# aside only until 'sf-cleanup' is run.
#
# Usage:
#   source test/manual-env.sh
#   cli dig <TAB>
#   cli direction -n car left
#   sf-cleanup     # restores .base-dir and undoes everything above

if [ -n "${_SF_MANUAL_ENV_DIR:-}" ]; then
    echo "manual-env.sh is already active in this shell - run 'sf-cleanup' first" >&2
    return 1 2>/dev/null || exit 1
fi

_SF_MANUAL_ENV_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
_SF_MANUAL_ENV_DIR=$(mktemp -d)
ln -s "$_SF_MANUAL_ENV_ROOT/cli.sh" "$_SF_MANUAL_ENV_DIR/cli"

if [ -f "$_SF_MANUAL_ENV_ROOT/.base-dir" ]; then
    mv "$_SF_MANUAL_ENV_ROOT/.base-dir" "$_SF_MANUAL_ENV_DIR/.base-dir.bak"
fi

export PATH="$_SF_MANUAL_ENV_DIR:$PATH"
export CLI_NAME=cli
source "$_SF_MANUAL_ENV_ROOT/cli-completion.bash"
complete -F _cli_completions cli

sf-cleanup() {
    complete -r cli 2>/dev/null || true
    if [ -f "$_SF_MANUAL_ENV_DIR/.base-dir.bak" ]; then
        mv "$_SF_MANUAL_ENV_DIR/.base-dir.bak" "$_SF_MANUAL_ENV_ROOT/.base-dir"
    fi
    rm -rf "$_SF_MANUAL_ENV_DIR"
    PATH="${PATH#"$_SF_MANUAL_ENV_DIR:"}"
    unset -f sf-cleanup
    unset _SF_MANUAL_ENV_DIR _SF_MANUAL_ENV_ROOT
    echo "manual test env cleaned up"
}

echo "manual test env ready - try: cli dig <TAB>, cli direction -n car left, cli group foo -v"
echo "run 'sf-cleanup' when done"
