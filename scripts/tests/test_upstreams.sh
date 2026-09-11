#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/update_upstreams.sh"
mkdir -p "$CACHE"
WORK=$(mktemp -d "$CACHE/text-tests.XXXXXX")
passed=0
expect_fail() {
    if ("$@") > "$WORK/expected-error.log" 2>&1; then fail "Expected failure: $*"; fi
    (( passed += 1 ))
}
# Prove the maintenance path never falls back to these runtimes.
mkdir -p "$WORK/blocked-bin"
for tool in jq python python3 node; do
    printf '#!/bin/sh\necho "Unexpected runtime" >&2\nexit 90\n' > "$WORK/blocked-bin/$tool"
    chmod +x "$WORK/blocked-bin/$tool"
done
export PATH="$WORK/blocked-bin:$PATH"
printf '%s\n' '[B](sub/b.md) **https://docs.comfy.org/cloud/mcp**' '[ref]: <hello%%20%%E4%%B8%%AD%%E6%%96%%87.md>' '<img src="asset.png">' > "$WORK/links.md"
text_tool links "$WORK/links.md" | sort > "$WORK/links"
printf '%s\n' asset.png 'hello%%20%%E4%%B8%%AD%%E6%%96%%87.md' https://docs.comfy.org/cloud/mcp sub/b.md | sort > "$WORK/expected-links"
cmp "$WORK/links" "$WORK/expected-links"
(( passed += 1 ))
printf '100644\ta.md\n100644\tsub/b.md\n100644\thello 中文.md\n' > "$WORK/tree"
printf '%s\n' sub/b.md 'hello%20%E4%B8%AD%E6%96%87.md' gone.md '%2e%2e/secret.md' https://example.com/a.md > "$WORK/links"
KIND=comfy-skills SOURCE_PATH=a.md LEVEL=0 DEPTH=1 text_tool resolve "$WORK/tree" "$WORK/links" > "$WORK/refs"
awk -F '\t' '$3=="sub/b.md" && $5=="bundled" {a=1} $4=="hello 中文.md" && $5=="bundled" {b=1} $3=="gone.md" && $5=="missing" {c=1} $5=="outside_scope" {d=1} $5=="external" {e=1} END {exit !(a&&b&&c&&d&&e)}' "$WORK/refs"
printf '../a.md\n' > "$WORK/links"
KIND=comfy-skills SOURCE_PATH=sub/b.md LEVEL=1 DEPTH=1 text_tool resolve "$WORK/tree" "$WORK/links" > "$WORK/refs"
grep -q $'a.md\tdepth_limit\t-' "$WORK/refs"
printf 'a.md\nsub/b.md\n' > "$WORK/seen"
KIND=comfy-skills text_tool finalize "$WORK/seen" "$WORK/refs" > "$WORK/final"
grep -q $'a.md\tbundled\t-' "$WORK/final"
(( passed += 1 ))

bundle_paths() { CONTENT="$WORK/fixture/files"; MANIFEST="$WORK/fixture/SOURCE.tsv"; }
bundle_paths fixture
mkdir -p "$CONTENT"
printf 'original\n' > "$CONTENT/a.md"
make_manifest() {
    local path=$1 name=$2 data=$3
    { printf 'meta\trepository\thttps://example.com/official\nmeta\tcommit\t0000000000000000000000000000000000000000\nmeta\treference_depth\t1\n'; printf 'file\t%s\t%s\t%s\nroot\t%s\n' "$name" "$(sha "$data")" "$name" "$name"; } | sort > "$path"
    manifest_json fixture "$path" "${path%.tsv}.json"
}
make_manifest "$MANIFEST" a.md "$CONTENT/a.md"
check_snapshot "$MANIFEST" "$CONTENT" fixture
printf 'human change\n' >> "$CONTENT/a.md"
expect_fail check_snapshot "$MANIFEST" "$CONTENT" fixture
grep -q 'human change' "$CONTENT/a.md"
printf 'original\n' > "$CONTENT/a.md"
printf 'keep\n' > "$CONTENT/human.md"
expect_fail check_snapshot "$MANIFEST" "$CONTENT" fixture
rm "$CONTENT/human.md"
ln -s a.md "$CONTENT/link.md"
expect_fail check_snapshot "$MANIFEST" "$CONTENT" fixture
rm "$CONTENT/link.md"
printf ' ' >> "${MANIFEST%.tsv}.json"
expect_fail check_snapshot "$MANIFEST" "$CONTENT" fixture
manifest_json fixture "$MANIFEST" "${MANIFEST%.tsv}.json"
backup_bundle fixture
mkdir -p "$WORK/candidate/fixture/files"
printf 'new\n' > "$WORK/candidate/fixture/files/b.md"
make_manifest "$WORK/candidate/fixture/SOURCE.tsv" b.md "$WORK/candidate/fixture/files/b.md"
printf ' ' >> "$MANIFEST"
expect_fail preflight_bundle fixture
cp "$WORK/before/fixture/SOURCE.tsv" "$MANIFEST"
apply_bundle fixture
[[ ! -e "$CONTENT/a.md" && -f "$CONTENT/b.md" ]]
check_snapshot "$MANIFEST" "$CONTENT" fixture
(( passed += 1 ))
# Invalid records and traversal cannot become filesystem operations.
printf 'file\t../escape\t123\t../escape\n' > "$WORK/invalid.tsv"
expect_fail text_tool validate "$WORK/invalid.tsv"
# JSON output preserves quotes/backslashes; no parser is used by maintenance.
printf 'meta\tscope\tquote " and backslash \\\n' > "$WORK/escape.tsv"
manifest_json fixture "$WORK/escape.tsv" "$WORK/escape.json"
grep -Fq 'quote \" and backslash \\' "$WORK/escape.json"
(( passed += 1 ))
printf '%s Shell checks passed. Evidence: %s\n' "$passed" "$WORK"
