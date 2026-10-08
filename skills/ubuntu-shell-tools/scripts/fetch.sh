#!/usr/bin/env bash
# Fetch shell_tools into a new directory under the current project's tmp/.
set -euo pipefail

SOURCE_REPO=https://github.com/0xdevelop/shell_tools.git
SOURCE_BRANCH=main

if [[ $# -ne 0 ]]; then
    printf 'Usage: run bash /path/to/ubuntu-shell-tools/scripts/fetch.sh from the task project root.\n' >&2
    exit 2
fi
command -v git >/dev/null 2>&1 || { printf 'Git is required.\n' >&2; exit 1; }

TASK_ROOT=$(pwd -P)
mkdir -p "$TASK_ROOT/tmp/shell-tools"
FETCH_DIR=$(mktemp -d "$TASK_ROOT/tmp/shell-tools/fetch.XXXXXXXX")
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=15}"

if ! git clone --quiet --depth=1 --single-branch --no-tags \
    --branch "$SOURCE_BRANCH" "$SOURCE_REPO" "$FETCH_DIR/source"; then
    printf 'Fetch failed; no scripts executed. Attempt directory: %s\n' "$FETCH_DIR" >&2
    exit 1
fi

SOURCE_COMMIT=$(git -C "$FETCH_DIR/source" rev-parse HEAD)
printf 'source\t%s\nref\t%s\ncommit\t%s\npath\t%s\n' \
    "$SOURCE_REPO" "$SOURCE_BRANCH" "$SOURCE_COMMIT" "$FETCH_DIR/source" \
    > "$FETCH_DIR/SOURCE.tsv"
cat "$FETCH_DIR/SOURCE.tsv"
