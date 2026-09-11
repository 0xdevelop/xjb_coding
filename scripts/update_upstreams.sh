#!/usr/bin/env bash
# Update pinned official sources using the tools supplied with Git Bash.
set -euo pipefail
export LC_ALL=C
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CACHE="$ROOT/tmp/upstreams"
THREE_REPO=https://github.com/mrdoob/three.js
COMFY_REPO=https://github.com/Comfy-Org/comfy-skills
WORK= LOCK= PHASE=preparing
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
text_tool() { local mode=$1; shift; MODE=$mode awk -f "$SCRIPT_DIR/upstream_text.awk" "$@"; }
sha() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else shasum -a 256 "$1" | awk '{print $1}'; fi
}
safe_path() {
    [[ -n "$1" && "$1" != - && "$1" != /* && "$1" != *\\* && "/$1/" != */../* && "/$1/" != */./* && ! "$1" =~ [[:cntrl:]] ]] || fail "Unsafe path: $1"
}
no_symlink() {
    local path=$1
    while [[ "$path" != / && "$path" != . ]]; do
        [[ ! -L "$path" ]] || fail "Symlink path: $path"
        path=$(dirname "$path")
    done
}
meta() { awk -F '\t' -v key="$2" '$1=="meta" && $2==key {print $3}' "$1"; }
file_names() { awk -F '\t' '$1=="file" {print $2}' "$1"; }
manifest_json() { KIND=$1 text_tool json "$2" > "$3"; }
bundle_paths() {
    case "$1" in
        threejs) CONTENT="$ROOT/skills/blender-threejs/references/threejs"; SOURCE="$ROOT/vendor/three.js"; REPO=$THREE_REPO; MANIFEST="$CONTENT/SOURCE.tsv" ;;
        comfy-skills) CONTENT="$ROOT/skills/comfyui-workflow/references/upstream/comfy-skills"; SOURCE="$CACHE/comfy-skills.git"; REPO=$COMFY_REPO; MANIFEST="$(dirname "$CONTENT")/SOURCE.tsv" ;;
        *) fail "Unknown source: $1" ;;
    esac
}
check_snapshot() {
    local manifest=$1 content=$2 kind=$3 name expected path record exclude=false
    no_symlink "$manifest"; no_symlink "$content"; no_symlink "${manifest%.tsv}.json"
    [[ -f "$manifest" && -d "$content" ]] || fail "Missing snapshot: $manifest"
    text_tool validate "$manifest"
    [[ -n "$(file_names "$manifest")" ]] || fail 'Empty snapshot'
    manifest_json "$kind" "$manifest" "$WORK/expected-source.json"
    cmp -s "$WORK/expected-source.json" "${manifest%.tsv}.json" || fail "Generated JSON was modified: ${manifest%.tsv}.json"
    [[ -z "$(find "$content" -type l -print -quit)" ]] || fail "Snapshot contains symlinks: $content"
    while IFS=$'\t' read -r record name expected path; do
        [[ "$record" == file ]] || continue
        safe_path "$name"
        [[ -f "$content/$name" && "$(sha "$content/$name")" == "$expected" ]] || fail "Missing or locally modified file: $content/$name"
    done < "$manifest"
    [[ "$(dirname "$manifest")" != "$content" ]] || exclude=true
    (cd "$content" && find . -type f -print) | sed 's#^./##' |
        awk -v exclude="$exclude" '!(exclude=="true" && ($0=="SOURCE.tsv" || $0=="SOURCE.json"))' | sort > "$WORK/actual-files"
    file_names "$manifest" | sort > "$WORK/expected-files"
    cmp -s "$WORK/actual-files" "$WORK/expected-files" || fail "Snapshot file list changed: $content"
}
clean_three() {
    [[ -z "$(git -C "$ROOT/vendor/three.js" status --porcelain --untracked-files=normal)" ]] || fail 'Three.js submodule has local changes'
    [[ "$(git -C "$ROOT/vendor/three.js" rev-parse HEAD)" == "$1" ]] || fail 'Three.js HEAD differs from the current snapshot'
}
check_bundle() {
    local kind=$1 commit verify=false depth
    bundle_paths "$kind"; check_snapshot "$MANIFEST" "$CONTENT" "$kind"
    commit=$(meta "$MANIFEST" commit)
    if [[ "$kind" == threejs && -e "$SOURCE/.git" ]]; then clean_three "$commit"; verify=true
    elif [[ "$kind" == comfy-skills && -d "$SOURCE" ]] && GIT_NO_LAZY_FETCH=1 git -C "$SOURCE" cat-file -e "$commit^{commit}" 2>/dev/null; then verify=true; fi
    if [[ "$verify" == true ]]; then
        depth=$(meta "$MANIFEST" reference_depth)
        GIT_NO_LAZY_FETCH=1 collect_bundle "$kind" "$commit" "$depth" "$WORK/check/$kind"
        cmp -s "$MANIFEST" "$WORK/check/$kind/SOURCE.tsv" || fail "Source/reference mismatch: $kind"
    fi
    printf '%s: %s files verified, %s\n' "$kind" "$(file_names "$MANIFEST" | wc -l | tr -d ' ')" "$commit"
}
collect_bundle() {
    local kind=$1 commit=$2 depth=$3 dest=$4 level path mode name bytes record header revision count=0
    local base="$WORK/collect-$kind"
    bundle_paths "$kind"
    [[ ! -e "$dest" ]] || fail "Candidate already exists: $dest"
    mkdir -p "$base" "$dest/files"
    git -C "$SOURCE" ls-tree -rz "$commit" > "$base/tree.raw"
    : > "$base/tree.tsv"
    while IFS= read -r -d '' record; do
        header=${record%%$'\t'*}; path=${record#*$'\t'}
        [[ "$header" == *' blob '* ]] || continue
        safe_path "$path"
        printf '%s\t%s\n' "${header%% *}" "$path" >> "$base/tree.tsv"
    done < "$base/tree.raw"
    if [[ "$kind" == threejs ]]; then
        printf 'docs/pages/%s.html.md\n' GLTFLoader AnimationMixer AnimationAction Timer Texture OrbitControls Points BufferGeometry ShaderMaterial MeshSurfaceSampler > "$base/roots"
        printf 'LICENSE\n' >> "$base/roots"
    else
        printf 'LICENSE\nREADME.md\n' > "$base/roots"
        awk -F '\t' '$2 ~ /^claude-code\/commands\/.*\.md$/ {print $2}' "$base/tree.tsv" >> "$base/roots"
        [[ $(wc -l < "$base/roots") -gt 2 ]] || fail 'Official commands directory changed; review extend rules'
    fi
    cp "$base/roots" "$base/queue"
    : > "$base/seen"; : > "$base/records"; : > "$base/references"
    printf 'meta\trepository\t%s\nmeta\tcommit\t%s\nmeta\treference_depth\t%s\n' "$REPO" "$commit" "$depth" >> "$base/records"
    awk '{print "root\t" $0}' "$base/roots" >> "$base/records"
    level=0
    while [[ -s "$base/queue" && $level -le $depth ]]; do
        : > "$base/level"
        while IFS= read -r path; do
            grep -Fqx -- "$path" "$base/seen" && continue
            safe_path "$path"
            mode=$(awk -F '\t' -v p="$path" '$2==p {print $1}' "$base/tree.tsv")
            [[ "$mode" == 100644 || "$mode" == 100755 ]] || fail "Missing regular upstream file: $path"
            name=$path; [[ "$kind" != threejs ]] || name=$(basename "$path")
            [[ ! -e "$dest/files/$name" ]] || fail "Duplicate output path: $name"
            (( count += 1 )); [[ $count -le 128 ]] || fail 'Bundle exceeds 128 files'
            bytes=$(git -C "$SOURCE" cat-file -s "$commit:$path")
            [[ $bytes -le 4194304 ]] || fail "File exceeds 4 MiB: $path"
            mkdir -p "$(dirname "$dest/files/$name")"
            git -C "$SOURCE" show "$commit:$path" > "$dest/files/$name"
            printf '%s\n' "$path" >> "$base/seen"
            printf 'file\t%s\t%s\t%s\n' "$name" "$(sha "$dest/files/$name")" "$path" >> "$base/records"
            case "$path" in *.md|*.mdx|*.html|*.txt)
                text_tool links "$dest/files/$name" | sort -u > "$base/links"
                KIND=$kind SOURCE_PATH=$path LEVEL=$level DEPTH=$depth text_tool resolve "$base/tree.tsv" "$base/links" >> "$base/level" ;;
            esac
        done < "$base/queue"
        cat "$base/level" >> "$base/references"
        awk -F '\t' '$5=="bundled" {print $4}' "$base/level" | sort -u > "$base/queue"
        (( level += 1 ))
    done
    KIND=$kind text_tool finalize "$base/seen" "$base/references" >> "$base/records"
    if [[ "$kind" == threejs ]]; then
        grep -Eq 'MIT License|Permission is hereby granted' "$dest/files/LICENSE" || fail 'Three.js license changed'
        git -C "$SOURCE" show "$commit:src/constants.js" > "$base/constants.js"
        revision=$(sed -n "s/^export const REVISION = '\([0-9][0-9]*\)';.*/\1/p" "$base/constants.js")
        [[ "$revision" =~ ^[0-9]+$ ]] || fail 'Three.js revision format changed'
        printf 'meta\trevision\t%s\n' "$revision" >> "$base/records"
    else
        [[ $(head -n 1 "$dest/files/LICENSE") == 'MIT License' ]] || fail 'Comfy Skills license changed'
        printf 'meta\tlicense\tMIT\nmeta\tscope\tOriginal commands and bounded local references; no plugin/MCP registration\n' >> "$base/records"
    fi
    sort "$base/records" > "$dest/SOURCE.tsv"
    text_tool validate "$dest/SOURCE.tsv"
    manifest_json "$kind" "$dest/SOURCE.tsv" "$dest/SOURCE.json"
}
backup_bundle() {
    local kind=$1 name
    bundle_paths "$kind"; check_snapshot "$MANIFEST" "$CONTENT" "$kind"
    mkdir -p "$WORK/before/$kind/files"
    cp "$MANIFEST" "$WORK/before/$kind/SOURCE.tsv"
    cp "${MANIFEST%.tsv}.json" "$WORK/before/$kind/SOURCE.json"
    file_names "$MANIFEST" > "$WORK/before/$kind/names"
    while IFS= read -r name; do
        mkdir -p "$(dirname "$WORK/before/$kind/files/$name")"; cp "$CONTENT/$name" "$WORK/before/$kind/files/$name"
    done < "$WORK/before/$kind/names"
}
preflight_bundle() {
    local kind=$1 name
    bundle_paths "$kind"
    cmp -s "$MANIFEST" "$WORK/before/$kind/SOURCE.tsv" || fail "Snapshot changed during preparation: $kind"
    check_snapshot "$MANIFEST" "$CONTENT" "$kind"
    check_snapshot "$WORK/candidate/$kind/SOURCE.tsv" "$WORK/candidate/$kind/files" "$kind"
    file_names "$WORK/candidate/$kind/SOURCE.tsv" > "$WORK/candidate/$kind/names"
    while IFS= read -r name; do safe_path "$name"; no_symlink "$CONTENT/$name"; done < "$WORK/candidate/$kind/names"
}
apply_bundle() {
    local kind=$1 name
    preflight_bundle "$kind"
    while IFS= read -r name; do
        mkdir -p "$(dirname "$CONTENT/$name")"; cp "$WORK/candidate/$kind/files/$name" "$CONTENT/$name"
    done < "$WORK/candidate/$kind/names"
    comm -23 "$WORK/before/$kind/names" "$WORK/candidate/$kind/names" > "$WORK/candidate/$kind/removed"
    while IFS= read -r name; do safe_path "$name"; rm "$CONTENT/$name"; done < "$WORK/candidate/$kind/removed"
    cp "$WORK/candidate/$kind/SOURCE.tsv" "$MANIFEST"
    cp "$WORK/candidate/$kind/SOURCE.json" "${MANIFEST%.tsv}.json"
}
check_api_links() {
    local url code resolved availability exit_code number=0
    : > "$WORK/api.tsv"
    text_tool links "$ROOT/skills/comfyui-workflow/references/local-api.md" | awk '/^https:\/\/docs.comfy.org\//' | sort -u > "$WORK/api-urls"
    while IFS= read -r url; do
        (( number += 1 )); exit_code=0
        curl --proto '=https' --proto-redir '=https' -ILsS --max-time 5 -o /dev/null -w '%{http_code}\n%{url_effective}\n' "$url" > "$WORK/http.txt" 2> "$WORK/http-$number.error" || exit_code=$?
        code=$(head -n 1 "$WORK/http.txt"); resolved=$(tail -n 1 "$WORK/http.txt"); availability=unknown
        if [[ $exit_code == 0 ]]; then
            if [[ "$code" == 2?? || "$code" == 3?? ]]; then availability=reachable; else availability=unavailable; fi
        fi
        printf '%s\t%s\t%s\t%s\n' "$url" "$code" "$resolved" "$availability" >> "$WORK/api.tsv"
        [[ "$availability" == reachable ]] || printf 'Online reference %s: %s\n' "$availability" "$url" >&2
    done < "$WORK/api-urls"
    text_tool api "$WORK/api.tsv" > "$WORK/api.json"
}
write_report() {
    local kind
    printf 'status\t%s\n' "$PHASE" > "$WORK/report.tsv"
    for kind in threejs comfy-skills; do
        printf 'source\t%s\t%s\t%s\n' "$kind" "$(meta "$WORK/before/$kind/SOURCE.tsv" commit)" "$(meta "$WORK/candidate/$kind/SOURCE.tsv" commit)" >> "$WORK/report.tsv"
        awk -F '\t' -v kind="$kind" '
            FNR==NR {if($1=="file") old[$2]=$3; next}
            $1=="file" {seen[$2]=1; if(!($2 in old)) print "added\t" kind "\t" $2; else if(old[$2]!=$3) print "changed\t" kind "\t" $2}
            END {for(p in old) if(!(p in seen)) print "removed\t" kind "\t" p}
        ' "$WORK/before/$kind/SOURCE.tsv" "$WORK/candidate/$kind/SOURCE.tsv" | sort >> "$WORK/report.tsv"
        awk -F '\t' -v kind="$kind" '$1=="ref" {n[$5]++} END {for(s in n) print "references\t" kind "\t" s "\t" n[s]}' "$WORK/candidate/$kind/SOURCE.tsv" | sort >> "$WORK/report.tsv"
    done
    REPORT_PATH="$WORK/report.json" text_tool report "$WORK/report.tsv" "$WORK/api.tsv" > "$WORK/report.json"
}
finish() {
    local code=$?
    trap - EXIT
    if [[ $code != 0 && -n "$WORK" ]]; then
        if [[ "$PHASE" == applying ]]; then PHASE=partial_failure; else PHASE=failed; fi
        printf '{"status":"%s","exit_code":%s}\n' "$PHASE" "$code" > "$WORK/failure.json"
        printf 'Update failed (%s). Evidence: %s\n' "$PHASE" "$WORK" >&2
    fi
    [[ -z "$LOCK" ]] || rmdir "$LOCK"
    exit "$code"
}
usage() {
    cat <<'USAGE'
Usage: bash scripts/update_upstreams.sh [--check | --dry-run]
       [--three-ref REF] [--comfy-ref REF] [--reference-depth 0..3]
Default: update latest official Three.js rN tag and Comfy Skills main.
--check: offline file hashes, original bytes and bundled references.
--dry-run: prepare candidates without changing snapshots or submodule HEAD.
Requires Bash 3.2+, Git, awk, grep, sed, curl, common Unix utilities and
sha256sum or shasum. Windows: standard Git Bash. No jq/Python/Node runtime.
USAGE
}
main() {
    local action=update depth=1 three_ref= comfy_ref=refs/heads/main arg old_commit three_commit comfy_commit latest
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h) usage; return ;;
            --check|--dry-run) [[ "$action" == update ]] || fail 'Choose one mode'; action=${1#--}; shift ;;
            --three-ref|--comfy-ref|--reference-depth)
                [[ $# -ge 2 ]] || fail "Missing value: $1"
                case "$1" in --three-ref) three_ref=$2;; --comfy-ref) comfy_ref=$2;; --reference-depth) depth=$2;; esac
                shift 2 ;;
            *) fail "Unknown argument: $1" ;;
        esac
    done
    [[ "$depth" =~ ^[0-3]$ ]] || fail 'Reference depth must be 0..3'
    for arg in "$three_ref" "$comfy_ref"; do
        [[ -z "$arg" || ( "$arg" =~ ^[A-Za-z0-9][A-Za-z0-9_./-]*$ && "$arg" != *..* ) ]] || fail "Invalid ref: $arg"
    done
    for arg in git awk grep sed curl sort find comm cmp mktemp; do command -v "$arg" >/dev/null 2>&1 || fail "Required tool not found: $arg"; done
    command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || fail 'Install sha256sum or shasum'
    mkdir -p "$CACHE"
    WORK=$(mktemp -d "$CACHE/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
    trap finish EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
    if [[ "$action" == check ]]; then check_bundle threejs; check_bundle comfy-skills; return; fi
    mkdir "$CACHE/update.lock.d" 2>/dev/null || fail 'Another update holds tmp/upstreams/update.lock.d; confirm it has stopped before removing a stale lock'
    LOCK="$CACHE/update.lock.d"
    [[ ! -e "$CACHE/update.lock" ]] || fail 'Previous updater lock exists; confirm that process has stopped'
    backup_bundle threejs; backup_bundle comfy-skills
    [[ $(git -C "$ROOT" ls-files --stage -- vendor/three.js) == '160000 '* ]] || fail 'vendor/three.js is not a registered submodule'
    [[ -e "$ROOT/vendor/three.js/.git" ]] || git -C "$ROOT" submodule update --init -- vendor/three.js
    old_commit=$(meta "$WORK/before/threejs/SOURCE.tsv" commit); clean_three "$old_commit"
    [[ -d "$CACHE/comfy-skills.git" ]] || git init --quiet --bare "$CACHE/comfy-skills.git"
    if [[ -z "$three_ref" ]]; then
        git ls-remote --tags --refs "$THREE_REPO" 'refs/tags/r*' > "$WORK/tags.txt"
        latest=$(awk '$2 ~ /^refs\/tags\/r[0-9]+$/ {sub(/^refs\/tags\/r/, "", $2); print $2}' "$WORK/tags.txt" | sort -n | tail -n 1)
        [[ -n "$latest" ]] || fail 'No official stable Three.js rN tag found'
        three_ref="refs/tags/r$latest"
    fi
    printf 'Fetch Three.js %s; Comfy Skills %s\n' "$three_ref" "$comfy_ref"
    git -C "$ROOT/vendor/three.js" fetch --no-tags --depth=1 "$THREE_REPO" "$three_ref"
    three_commit=$(git -C "$ROOT/vendor/three.js" rev-parse 'FETCH_HEAD^{commit}')
    git -C "$CACHE/comfy-skills.git" fetch --no-tags --depth=1 "$COMFY_REPO" "$comfy_ref"
    comfy_commit=$(git -C "$CACHE/comfy-skills.git" rev-parse 'FETCH_HEAD^{commit}')
    collect_bundle threejs "$three_commit" "$depth" "$WORK/candidate/threejs"
    collect_bundle comfy-skills "$comfy_commit" "$depth" "$WORK/candidate/comfy-skills"
    check_api_links; preflight_bundle threejs; preflight_bundle comfy-skills
    PHASE=prepared; write_report
    if [[ "$action" != dry-run ]]; then
        clean_three "$old_commit"; PHASE=applying
        [[ "$three_commit" == "$old_commit" ]] || git -C "$ROOT/vendor/three.js" checkout --detach --no-overwrite-ignore "$three_commit"
        apply_bundle threejs; apply_bundle comfy-skills
        check_bundle threejs; check_bundle comfy-skills
        PHASE=updated; write_report
    fi
    cat "$WORK/report.tsv"
    printf 'Evidence: %s\n' "$WORK"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
