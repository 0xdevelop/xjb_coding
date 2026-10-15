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
LAYOUT=tree SOURCE_PATH=a.md LEVEL=0 DEPTH=1 text_tool resolve "$WORK/tree" "$WORK/links" > "$WORK/refs"
awk -F '\t' '$3=="sub/b.md" && $5=="bundled" {a=1} $4=="hello 中文.md" && $5=="bundled" {b=1} $3=="gone.md" && $5=="missing" {c=1} $5=="outside_scope" {d=1} $5=="external" {e=1} END {exit !(a&&b&&c&&d&&e)}' "$WORK/refs"
printf '../a.md\n' > "$WORK/links"
LAYOUT=tree SOURCE_PATH=sub/b.md LEVEL=1 DEPTH=1 text_tool resolve "$WORK/tree" "$WORK/links" > "$WORK/refs"
grep -q $'a.md\tdepth_limit\t-' "$WORK/refs"
printf 'a.md\nsub/b.md\n' > "$WORK/seen"
LAYOUT=tree text_tool finalize "$WORK/seen" "$WORK/refs" > "$WORK/final"
grep -q $'a.md\tbundled\t-' "$WORK/final"
(( passed += 1 ))

# Preserve flat documentation link mappings without binding the resolver to a repository name.
printf '100644\tdocs/pages/a.html.md\n100644\tdocs/pages/b.html.md\n' > "$WORK/flat-tree"
printf '%s\n' b.html https://docs.example.invalid/docs/pages/b.html http://docs.example.invalid/docs/pages/b.html https://docs.example.invalid/manual/ > "$WORK/flat-links"
REFERENCE_PREFIX=docs/pages/ URL_PREFIX=https://docs.example.invalid/ HTML_SUFFIX=.md SOURCE_PATH=docs/pages/a.html.md LEVEL=0 DEPTH=1 text_tool resolve "$WORK/flat-tree" "$WORK/flat-links" > "$WORK/flat-refs"
[[ $(awk -F '\t' '$5=="bundled" {n++} END {print n}' "$WORK/flat-refs") == 3 ]]
grep -q $'manual/\t-\texternal' "$WORK/flat-refs"
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


# A new reference snapshot must work without changing updater source code.
FIXTURE_ROOT="$WORK/discovery"
UPSTREAM_REPO="$WORK/official-source.git"
mkdir -p "$FIXTURE_ROOT/scripts" "$UPSTREAM_REPO/commands"
cp "$SCRIPT_DIR/update_upstreams.sh" "$SCRIPT_DIR/upstream_text.awk" "$FIXTURE_ROOT/scripts/"
git -C "$UPSTREAM_REPO" init --quiet
printf 'MIT License\n' > "$UPSTREAM_REPO/LICENSE"
printf '[command](commands/old.md)\n' > "$UPSTREAM_REPO/README.md"
printf 'old command\n' > "$UPSTREAM_REPO/commands/old.md"
git -C "$UPSTREAM_REPO" add -- LICENSE README.md commands/old.md
git -C "$UPSTREAM_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m initial
OLD_COMMIT=$(git -C "$UPSTREAM_REPO" rev-parse HEAD)
for id in new-reference another-reference; do
    SNAPSHOT="$FIXTURE_ROOT/skills/example/references/$id"
    mkdir -p "$SNAPSHOT"
    git -C "$UPSTREAM_REPO" archive HEAD | tar -x -C "$SNAPSHOT"
    {
        printf 'meta\trepository\t%s\nmeta\tcommit\t%s\nmeta\treference_depth\t1\n' "$UPSTREAM_REPO" "$OLD_COMMIT"
        for name in LICENSE README.md commands/old.md; do
            printf 'root\t%s\nfile\t%s\t%s\t%s\n' "$name" "$name" "$(sha "$SNAPSHOT/$name")" "$name"
        done
    } | sort > "$SNAPSHOT/SOURCE.tsv"
    LAYOUT=tree manifest_json fixture "$SNAPSHOT/SOURCE.tsv" "$SNAPSHOT/SOURCE.json"
done
git -C "$UPSTREAM_REPO" mv commands/old.md commands/new.md
printf '[command](commands/new.md)\n' > "$UPSTREAM_REPO/README.md"
git -C "$UPSTREAM_REPO" add -- README.md commands/new.md
git -C "$UPSTREAM_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m update
NEW_COMMIT=$(git -C "$UPSTREAM_REPO" rev-parse HEAD)
bash "$FIXTURE_ROOT/scripts/update_upstreams.sh" --dry-run > "$WORK/discovery-dry-run.log" 2>&1
[[ $(meta "$SNAPSHOT/SOURCE.tsv" commit) == "$OLD_COMMIT" ]]
bash "$FIXTURE_ROOT/scripts/update_upstreams.sh" > "$WORK/discovery-update.log" 2>&1
for id in new-reference another-reference; do
    SNAPSHOT="$FIXTURE_ROOT/skills/example/references/$id"
    [[ $(meta "$SNAPSHOT/SOURCE.tsv" commit) == "$NEW_COMMIT" ]]
    [[ ! -f "$SNAPSHOT/commands/old.md" && -f "$SNAPSHOT/commands/new.md" ]]
    cmp "$SNAPSHOT/README.md" "$UPSTREAM_REPO/README.md"
done
bash "$FIXTURE_ROOT/scripts/update_upstreams.sh" --check > "$WORK/discovery-check.log" 2>&1
(( passed += 1 ))
# An edited snapshot is rejected before replacement, and the lock is released.
printf 'human edit\n' >> "$SNAPSHOT/README.md"
expect_fail bash "$FIXTURE_ROOT/scripts/update_upstreams.sh"
grep -q 'human edit' "$SNAPSHOT/README.md"
[[ ! -d "$FIXTURE_ROOT/tmp/upstreams/update.lock.d" ]]
# Unregistered submodules cannot silently fall outside the update loop.
printf '[submodule "unregistered"]\n\tpath = vendor/unregistered\n\turl = https://example.invalid/official.git\n' > "$FIXTURE_ROOT/.gitmodules"
expect_fail bash "$FIXTURE_ROOT/scripts/update_upstreams.sh" --check


# Exercise the submodule path and keep its numeric tag policy after a no-tags fetch.
SUBMODULE_ROOT="$WORK/submodule-discovery"
mkdir -p "$SUBMODULE_ROOT/scripts" "$SUBMODULE_ROOT/skills/example/references"
cp "$SCRIPT_DIR/update_upstreams.sh" "$SCRIPT_DIR/upstream_text.awk" "$SUBMODULE_ROOT/scripts/"
cp -R "$FIXTURE_ROOT/skills/example/references/new-reference" "$SUBMODULE_ROOT/skills/example/references/"
SNAPSHOT="$SUBMODULE_ROOT/skills/example/references/new-reference"
printf 'meta\trevision\t1\n' >> "$SNAPSHOT/SOURCE.tsv"
sort "$SNAPSHOT/SOURCE.tsv" -o "$SNAPSHOT/SOURCE.tsv"
LAYOUT=tree manifest_json fixture "$SNAPSHOT/SOURCE.tsv" "$SNAPSHOT/SOURCE.json"
git -C "$UPSTREAM_REPO" tag r1 "$NEW_COMMIT"
git -C "$SUBMODULE_ROOT" init --quiet
# Local repository aliases must match the snapshot's original repository path.
git -C "$SUBMODULE_ROOT" -c protocol.file.allow=always submodule add --quiet "$UPSTREAM_REPO/." vendor/official
git -C "$SUBMODULE_ROOT" add -- scripts skills .gitmodules vendor/official
git -C "$SUBMODULE_ROOT" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m reference
printf 'newer command\n' > "$UPSTREAM_REPO/commands/new.md"
git -C "$UPSTREAM_REPO" add -- commands/new.md
git -C "$UPSTREAM_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m newer
LATEST_COMMIT=$(git -C "$UPSTREAM_REPO" rev-parse HEAD)
git -C "$UPSTREAM_REPO" tag r2
GIT_ALLOW_PROTOCOL=file bash "$SUBMODULE_ROOT/scripts/update_upstreams.sh" --dry-run > "$WORK/submodule-dry-run.log" 2>&1
[[ $(git -C "$SUBMODULE_ROOT/vendor/official" rev-parse HEAD) == "$NEW_COMMIT" ]]
GIT_ALLOW_PROTOCOL=file bash "$SUBMODULE_ROOT/scripts/update_upstreams.sh" > "$WORK/submodule-update.log" 2>&1
[[ $(git -C "$SUBMODULE_ROOT/vendor/official" rev-parse HEAD) == "$LATEST_COMMIT" ]]
[[ $(meta "$SNAPSHOT/SOURCE.tsv" revision) == 2 ]]
cmp "$SNAPSHOT/commands/new.md" "$UPSTREAM_REPO/commands/new.md"
GIT_ALLOW_PROTOCOL=file bash "$SUBMODULE_ROOT/scripts/update_upstreams.sh" --dry-run > "$WORK/submodule-repeat.log" 2>&1
grep -q 'Fetch new-reference refs/tags/r2' "$WORK/submodule-repeat.log"
bash "$SUBMODULE_ROOT/scripts/update_upstreams.sh" --check > "$WORK/submodule-check.log" 2>&1
(( passed += 1 ))


# First import generates manifests from existing submodule metadata.
BOOTSTRAP_ROOT="$WORK/bootstrap"
mkdir -p "$BOOTSTRAP_ROOT/scripts" "$BOOTSTRAP_ROOT/skills"
cp "$SCRIPT_DIR/update_upstreams.sh" "$SCRIPT_DIR/upstream_text.awk" "$BOOTSTRAP_ROOT/scripts/"
git -C "$BOOTSTRAP_ROOT" init --quiet
git -C "$BOOTSTRAP_ROOT" -c protocol.file.allow=always submodule add --quiet "$UPSTREAM_REPO" vendor/official
git -C "$BOOTSTRAP_ROOT" config -f .gitmodules submodule.vendor/official.references skills/example/references/automatic
git -C "$BOOTSTRAP_ROOT" add -- .gitmodules vendor/official scripts
git -C "$BOOTSTRAP_ROOT" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m source
GIT_ALLOW_PROTOCOL=file bash "$BOOTSTRAP_ROOT/scripts/update_upstreams.sh" --dry-run > "$WORK/bootstrap-dry-run.log" 2>&1
[[ ! -e "$BOOTSTRAP_ROOT/skills/example/references/automatic" ]]
GIT_ALLOW_PROTOCOL=file bash "$BOOTSTRAP_ROOT/scripts/update_upstreams.sh" > "$WORK/bootstrap-update.log" 2>&1
SNAPSHOT="$BOOTSTRAP_ROOT/skills/example/references/automatic"
[[ -f "$SNAPSHOT/SOURCE.tsv" && -f "$SNAPSHOT/SOURCE.json" ]]
[[ $(meta "$SNAPSHOT/SOURCE.tsv" commit) == "$LATEST_COMMIT" ]]
cmp "$SNAPSHOT/commands/new.md" "$UPSTREAM_REPO/commands/new.md"
bash "$BOOTSTRAP_ROOT/scripts/update_upstreams.sh" --check > "$WORK/bootstrap-check.log" 2>&1
(( passed += 1 ))


# Runtime packages keep directory roots so future imports/assets are included.
PACKAGE_ROOT="$WORK/runtime-package"
mkdir -p "$PACKAGE_ROOT/scripts" "$UPSTREAM_REPO/package/bin"
cp "$SCRIPT_DIR/update_upstreams.sh" "$SCRIPT_DIR/upstream_text.awk" "$PACKAGE_ROOT/scripts/"
for ((index=0; index<130; index++)); do
    printf 'export default %s;\n' "$index" > "$UPSTREAM_REPO/package/bin/module-$index.mjs"
done
git -C "$UPSTREAM_REPO" add -- package
git -C "$UPSTREAM_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m package
git -C "$PACKAGE_ROOT" init --quiet
git -C "$PACKAGE_ROOT" -c protocol.file.allow=always submodule add --quiet "$UPSTREAM_REPO" vendor/official
git -C "$PACKAGE_ROOT" config -f .gitmodules submodule.vendor/official.references skills/example/references/runtime
git -C "$PACKAGE_ROOT" config -f .gitmodules --add submodule.vendor/official.referenceRoot package
GIT_ALLOW_PROTOCOL=file bash "$PACKAGE_ROOT/scripts/update_upstreams.sh" > "$WORK/package-import.log" 2>&1
SNAPSHOT="$PACKAGE_ROOT/skills/example/references/runtime"
[[ $(file_names "$SNAPSHOT/SOURCE.tsv" | wc -l | tr -d ' ') == 131 ]]
grep -Fxq $'root\tpackage' "$SNAPSHOT/SOURCE.tsv"
# Continue as a cached source, as a distributed Skill does without a submodule.
rm "$PACKAGE_ROOT/.gitmodules"
git -C "$UPSTREAM_REPO" rm --quiet package/bin/module-0.mjs
printf 'new runtime asset\n' > "$UPSTREAM_REPO/package/new.bin"
git -C "$UPSTREAM_REPO" add -- package/new.bin
git -C "$UPSTREAM_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m asset
bash "$PACKAGE_ROOT/scripts/update_upstreams.sh" > "$WORK/package-update.log" 2>&1
[[ ! -e "$SNAPSHOT/package/bin/module-0.mjs" && -f "$SNAPSHOT/package/new.bin" ]]
cmp "$SNAPSHOT/package/new.bin" "$UPSTREAM_REPO/package/new.bin"
bash "$PACKAGE_ROOT/scripts/update_upstreams.sh" --check > "$WORK/package-check.log" 2>&1
(( passed += 1 ))
PACKAGE_BEFORE=$(sha "$SNAPSHOT/SOURCE.tsv")
git -C "$UPSTREAM_REPO" rm -rq package
git -C "$UPSTREAM_REPO" -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m removed-package
expect_fail bash "$PACKAGE_ROOT/scripts/update_upstreams.sh"
[[ $(sha "$SNAPSHOT/SOURCE.tsv") == "$PACKAGE_BEFORE" && -f "$SNAPSHOT/package/new.bin" ]]


FAILURE_SNAPSHOT="$FIXTURE_ROOT/skills/example/references/zzz-failure"
cp -R "$FIXTURE_ROOT/skills/example/references/new-reference" "$FAILURE_SNAPSHOT"
awk -F '\t' -v OFS='\t' -v repo="$WORK/nonexistent.git" '{if($1=="meta" && $2=="repository") $3=repo; print}' "$FAILURE_SNAPSHOT/SOURCE.tsv" > "$WORK/unreachable.tsv"
cp "$WORK/unreachable.tsv" "$FAILURE_SNAPSHOT/SOURCE.tsv"
LAYOUT=tree manifest_json fixture "$FAILURE_SNAPSHOT/SOURCE.tsv" "$FAILURE_SNAPSHOT/SOURCE.json"
rm "$FIXTURE_ROOT/.gitmodules"
cp "$FIXTURE_ROOT/skills/example/references/new-reference/README.md" "$FIXTURE_ROOT/skills/example/references/another-reference/README.md"
BEFORE_FAILURE=$(sha "$FIXTURE_ROOT/skills/example/references/new-reference/SOURCE.tsv")
expect_fail bash "$FIXTURE_ROOT/scripts/update_upstreams.sh"
[[ $(sha "$FIXTURE_ROOT/skills/example/references/new-reference/SOURCE.tsv") == "$BEFORE_FAILURE" ]]
[[ ! -d "$FIXTURE_ROOT/tmp/upstreams/update.lock.d" ]]


# Run only the actual pre-release preparation function against a failing fixture.
sed -n '/^function git_handle_ready()/,/^}/p' "$SCRIPT_DIR/../git_tag.sh" > "$WORK/release-ready.sh"
cat > "$WORK/release-guard.sh" <<'GUARD'
set -e
VersionFile=$1
SyncFile=$1
PluginJsonFile=$1
CodexPluginJsonFile=$1
CURRENT_VERSION=v0.0.0
NEXT_VERSION=v0.0.1
OS_TYPE=Linux
source "$2"
git_handle_ready
printf 'continued\n' > "$3"
GUARD
printf 'version untouched\n' > "$WORK/release-version"
run_failed_release() { (cd "$FIXTURE_ROOT" && bash "$WORK/release-guard.sh" "$WORK/release-version" "$WORK/release-ready.sh" "$WORK/release-continued"); }
expect_fail run_failed_release
[[ $(cat "$WORK/release-version") == 'version untouched' && ! -e "$WORK/release-continued" ]]
printf '%s Shell checks passed. Evidence: %s\n' "$passed" "$WORK"
