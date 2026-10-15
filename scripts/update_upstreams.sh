#!/usr/bin/env bash
# Update pinned official sources using the tools supplied with Git Bash.
set -euo pipefail
export LC_ALL=C
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CACHE="$ROOT/tmp/upstreams"
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
manifest_json() { LAYOUT="${LAYOUT:-tree}" text_tool json "$2" > "$3"; }
setting() { awk -F '\t' -v id="$1" -v key="$2" '$1==id && $2==key {print $3}' "${CONFIG:-/dev/null}"; }
source_ids() { awk -F '\t' '!/^#/ && NF {print $1}' "$CONFIG" | sort -u; }
repository_key() {
    local url=$1 directory
    if [[ -d "$url" ]] && directory=$(git -C "$url" rev-parse --absolute-git-dir 2>/dev/null); then
        printf '%s\n' "$directory"
        return
    fi
    url=${url%.git}
    url=${url#https://}; url=${url#http://}; url=${url#ssh://git@}; url=${url#git@}
    printf '%s\n' "${url/:/\/}"
}
initialize_source() {
    local module_key=$1 submodule=$2 target id repo first license root branch clean_source_path
    target=$(git config -f "$ROOT/.gitmodules" --get "$module_key.references" || true)
    [[ -n "$target" ]] || fail "Submodule needs a reference output path in .gitmodules ($module_key.references): $submodule"
    safe_path "$target"; no_symlink "$ROOT/$target"
    [[ "$target" == skills/*/references/* ]] || fail "Reference output must be under skills/<skill>/references/: $target"
    [[ ! -e "$ROOT/$target" ]] || fail "Initial reference output already exists: $target"
    id=$(basename "$target")
    [[ "$id" =~ ^[a-z0-9][a-z0-9-]*$ && -z "$(setting "$id" manifest)" ]] || fail "Invalid/duplicate reference name: $id"
    [[ -e "$ROOT/$submodule/.git" ]] || fail "Initialize submodule first: $submodule"
    clean_source_path="$ROOT/$submodule"
    [[ -z "$(git -C "$clean_source_path" status --porcelain --untracked-files=normal)" ]] || fail "Submodule has local changes: $submodule"
    repo=$(git config -f "$ROOT/.gitmodules" --get "$module_key.url")
    branch=$(git config -f "$ROOT/.gitmodules" --get "$module_key.branch" || true)
    git -C "$clean_source_path" ls-tree -r --name-only HEAD > "$WORK/initial-tree"
    first=$(awk '/^(LICENSE([.][^\/]+)?|COPYING)$/ {print; exit}' "$WORK/initial-tree")
    [[ -n "$first" ]] || fail "No license file in submodule: $submodule"
    git -C "$clean_source_path" show "HEAD:$first" > "$WORK/initial-license"
    if grep -Eq 'MIT License|Permission is hereby granted' "$WORK/initial-license"; then license=MIT
    elif grep -Eq 'Redistribution and use in source and binary forms' "$WORK/initial-license"; then license=BSD
    elif grep -Eq 'Apache License' "$WORK/initial-license"; then license=Apache
    else fail "Unsupported license: $submodule"; fi
    printf '%s\tstorage\tsubmodule\n%s\tsubmodule\t%s\n%s\trepository\t%s\n%s\tref\t%s\n' "$id" "$id" "$submodule" "$id" "$repo" "$id" "${branch:-HEAD}" >> "$CONFIG"
    printf '%s\tmanifest\t%s/SOURCE.tsv\n%s\tcontent\t%s\n%s\tlayout\ttree\n%s\tinitial\tyes\n' "$id" "$target" "$id" "$target" "$id" "$id" >> "$CONFIG"
    printf '%s\tlicense\t%s\n%s\tlicense_metadata\tyes\n%s\tlicense_file\t%s\n%s\troot\t%s\n' "$id" "$license" "$id" "$id" "$first" "$id" "$first" >> "$CONFIG"
    git config -f "$ROOT/.gitmodules" --get-all "$module_key.referenceRoot" > "$WORK/initial-roots" || true
    if [[ ! -s "$WORK/initial-roots" ]]; then
        awk '/^README([.]md)?$/ || /(^|\/)SKILL[.]md$/ || /(^|\/)commands\/[^\/]+[.]md$/ {print}' "$WORK/initial-tree" > "$WORK/initial-roots"
    fi
    while IFS= read -r root; do
        safe_path "$root"
        awk -v id="$id" -v path="${root%/}" '$0==path || index($0,path "/")==1 {print id "\troot\t" $0; found=1} END {exit !found}' "$WORK/initial-tree" >> "$CONFIG" || fail "Reference root missing: $root"
    done < "$WORK/initial-roots"
}
discover_upstreams() {
    CONFIG="$WORK/upstreams.tsv"
    : > "$CONFIG"
    local manifest directory content id repo module_key submodule branch tag prefix value first candidate matches declared
    : > "$WORK/manifests"
    [[ ! -d "$ROOT/skills" ]] || find "$ROOT/skills" -type f -name SOURCE.tsv | sort > "$WORK/manifests"
    while IFS= read -r manifest; do
        text_tool validate "$manifest"
        directory=$(dirname "$manifest"); first=$(awk -F '\t' '$1=="file" {print $2; exit}' "$manifest")
        content=; matches=0
        for candidate in "$directory" "$directory"/*; do
            [[ -d "$candidate" && -f "$candidate/$first" ]] || continue
            content=$candidate; (( matches += 1 ))
        done
        [[ "$matches" == 1 ]] || fail "Cannot identify a unique reference directory: $manifest"
        id=$(basename "$content")
        [[ "$id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "Reference directory must use a stable kebab-case name: $content"
        [[ -z "$(setting "$id" manifest)" ]] || fail "Duplicate reference directory name: $id"
        repo=$(meta "$manifest" repository)
        printf '%s\tmanifest\t%s\n%s\tcontent\t%s\n%s\trepository\t%s\n' "$id" "${manifest#"$ROOT/"}" "$id" "${content#"$ROOT/"}" "$id" "$repo" >> "$CONFIG"
        value=$(awk -F '\t' '$1=="file" && $2!=$4 {found=1} END {print found ? "flat" : "tree"}' "$manifest")
        printf '%s\tlayout\t%s\n' "$id" "$value" >> "$CONFIG"
        if [[ "$value" == flat ]]; then
            prefix=$(awk -F '\t' '$1=="root" && $2 ~ /\// {sub(/[^\/]*$/, "", $2); print $2; exit}' "$manifest")
            printf '%s\treference_prefix\t%s\n%s\thtml_suffix\t.md\n' "$id" "$prefix" "$id" >> "$CONFIG"
        fi
        awk -F '\t' -v id="$id" '$1=="root" && $2 !~ /(^|\/)commands\/[^\/]+[.]md$/ {print id "\troot\t" $2}' "$manifest" >> "$CONFIG"
        if awk -F '\t' '$1=="root" && $2 ~ /(^|\/)SKILL[.]md$/ {found=1} END {exit !found}' "$manifest"; then
            printf '%s\troot_pattern\t(^|/)SKILL[.]md$\n' "$id" >> "$CONFIG"
            awk -F '\t' -v id="$id" '!($1==id && $2=="root" && $3 ~ /(^|\/)SKILL[.]md$/)' "$CONFIG" > "$WORK/skill-roots.tsv"
            mv "$WORK/skill-roots.tsv" "$CONFIG"
        fi
        # Existing command directories define the scope for new command files.
        awk -F '\t' -v id="$id" '$1=="root" && $2 ~ /(^|\/)commands\/[^\/]+[.]md$/ {sub(/[^\/]*$/, "", $2); if(!seen[$2]++) print id "\troot_pattern\t^" $2 "[^\/]+[.]md$"}' "$manifest" >> "$CONFIG"
        value=$(meta "$manifest" license)
        if [[ -n "$value" ]]; then printf '%s\tlicense\t%s\n%s\tlicense_metadata\tyes\n' "$id" "$value" "$id" >> "$CONFIG"; fi
        first=$(awk -F '\t' '$1=="file" && $4 ~ /(^|\/)(LICENSE|LICENSE[.][^\/]+|COPYING)$/ {print $2; exit}' "$manifest")
        [[ -n "$first" ]] || fail "No license file registered: $manifest"
        if [[ -z "$value" ]]; then
            if grep -Eq 'MIT License|Permission is hereby granted' "$content/$first"; then value=MIT
            elif grep -Eq 'Redistribution and use in source and binary forms' "$content/$first"; then value=BSD
            elif grep -Eq 'Apache License' "$content/$first"; then value=Apache
            else fail "Unsupported license: $manifest"; fi
            printf '%s\tlicense\t%s\n' "$id" "$value" >> "$CONFIG"
        fi
        value=$(awk -F '\t' -v file="$first" '$1=="file" && $2==file {print $4}' "$manifest")
        printf '%s\tlicense_file\t%s\n' "$id" "$value" >> "$CONFIG"
        for prefix in scope revision; do
            value=$(meta "$manifest" "$prefix")
            [[ -z "$value" ]] || printf '%s\t%s\t%s\n' "$id" "$prefix" "$value" >> "$CONFIG"
        done
        module_key=
        if [[ -f "$ROOT/.gitmodules" ]]; then
            while IFS= read -r candidate; do
                value=$(git config -f "$ROOT/.gitmodules" --get "$candidate")
                if [[ "$(repository_key "$value")" == "$(repository_key "$repo")" ]]; then module_key=${candidate%.url}; break; fi
            done < <(git config -f "$ROOT/.gitmodules" --name-only --get-regexp '^submodule[.].*[.]url$' || true)
        fi
        if [[ -n "$module_key" ]]; then
            submodule=$(git config -f "$ROOT/.gitmodules" --get "$module_key.path")
            declared=$(git config -f "$ROOT/.gitmodules" --get "$module_key.references" || true)
            [[ -z "$declared" || "$ROOT/$declared" == "$content" ]] || fail "Reference output differs from .gitmodules: $manifest"
            printf '%s\tstorage\tsubmodule\n%s\tsubmodule\t%s\n' "$id" "$id" "$submodule" >> "$CONFIG"
            branch=$(git config -f "$ROOT/.gitmodules" --get "$module_key.branch" || true)
            tag=; prefix=
            if [[ -z "$branch" && -n "$(meta "$manifest" revision)" && -e "$ROOT/$submodule/.git" ]]; then
                tag=$(git -C "$ROOT/$submodule" tag --points-at "$(meta "$manifest" commit)" | awk '/^[A-Za-z-]*[0-9]+$/ && !found {print; found=1}')
                if [[ -z "$tag" && -n "$(meta "$manifest" revision)" ]]; then
                    tag=$(git -C "$ROOT/$submodule" tag --list | awk '/^[A-Za-z-]+[0-9]+$/ && !found {print; found=1}')
                fi
                [[ -z "$tag" ]] || prefix=${tag%%[0-9]*}
            fi
            if [[ -n "$prefix" ]]; then printf '%s\ttag_prefix\t%s\n' "$id" "$prefix" >> "$CONFIG"
            else printf '%s\tref\t%s\n' "$id" "${branch:-HEAD}" >> "$CONFIG"; fi
        else printf '%s\tstorage\tcache\n%s\tref\tHEAD\n' "$id" "$id" >> "$CONFIG"; fi
    done < "$WORK/manifests"
    if [[ -f "$ROOT/.gitmodules" ]]; then
        while IFS= read -r candidate; do
            submodule=$(git config -f "$ROOT/.gitmodules" --get "$candidate")
            if ! awk -F '\t' -v path="$submodule" '$2=="submodule" && $3==path {found=1} END {exit !found}' "$CONFIG"; then
                [[ "${action:-check}" != check ]] || fail "Submodule has no SOURCE.tsv reference snapshot: $submodule"
                initialize_source "${candidate%.path}" "$submodule"
            fi
        done < <(git config -f "$ROOT/.gitmodules" --name-only --get-regexp '^submodule[.].*[.]path$' || true)
    fi
    source_ids > "$WORK/sources"
    [[ -s "$WORK/sources" ]] || fail 'No upstream references found'
    while IFS= read -r id; do bundle_paths "$id"; done < "$WORK/sources"
}
bundle_paths() {
    local id=$1 relative key module_key
    STORAGE=$(setting "$id" storage); LAYOUT=$(setting "$id" layout)
    [[ "$STORAGE" == submodule || "$STORAGE" == cache ]] || fail "Invalid storage: $id"
    [[ "$LAYOUT" == flat || "$LAYOUT" == tree ]] || fail "Invalid layout: $id"
    relative=$(setting "$id" content); safe_path "$relative"; CONTENT="$ROOT/$relative"
    relative=$(setting "$id" manifest); safe_path "$relative"; MANIFEST="$ROOT/$relative"
    [[ "$MANIFEST" == */SOURCE.tsv ]] || fail "Manifest must be SOURCE.tsv: $id"
    LICENSE_KIND=$(setting "$id" license); LICENSE_FILE=$(setting "$id" license_file); safe_path "$LICENSE_FILE"
    [[ "$LICENSE_KIND" == MIT || "$LICENSE_KIND" == BSD || "$LICENSE_KIND" == Apache ]] || fail "Unsupported license: $id"
    REPO=$(setting "$id" repository); MODULE_KEY=
    if [[ "$STORAGE" == submodule ]]; then
        relative=$(setting "$id" submodule); safe_path "$relative"; SOURCE="$ROOT/$relative"
        module_key=$(git config -f "$ROOT/.gitmodules" --get-regexp '^submodule[.].*[.]path$' | awk -v path="$relative" 'substr($0,index($0," ")+1)==path {sub(/[.]path$/, ".url", $1); print $1}')
        [[ -n "$module_key" ]] || fail "Unregistered submodule: $relative"
        MODULE_KEY=${module_key%.url}
    else SOURCE="$CACHE/$id.git"; fi
    [[ -n "$REPO" ]] || fail "Missing repository: $id"
    REF=$(setting "$id" ref); TAG_PREFIX=$(setting "$id" tag_prefix)
    [[ -n "$REF" || -n "$TAG_PREFIX" ]] || fail "Missing ref policy: $id"
    [[ -z "$REF" || -z "$TAG_PREFIX" ]] || fail "Choose ref or tag_prefix: $id"
    for key in "$REF" "$TAG_PREFIX"; do
        [[ -z "$key" || ( "$key" =~ ^[A-Za-z0-9][A-Za-z0-9_./-]*$ && "$key" != *..* ) ]] || fail "Invalid ref policy: $id"
    done
    REFERENCE_PREFIX=$(setting "$id" reference_prefix)
    URL_PREFIX=; HTML_SUFFIX=$(setting "$id" html_suffix)
    if [[ -n "$MODULE_KEY" ]]; then
        URL_PREFIX=$(git config -f "$ROOT/.gitmodules" --get "$MODULE_KEY.referenceUrl" || true)
        if [[ -n "$URL_PREFIX" ]]; then [[ "$URL_PREFIX" == https://* || "$URL_PREFIX" == http://* ]] || fail "Invalid reference URL: $id"; fi
    fi
}
clean_submodule() {
    [[ -z "$(git -C "$SOURCE" status --porcelain --untracked-files=normal)" ]] || fail "Submodule has local changes: $SOURCE"
    [[ "$(git -C "$SOURCE" rev-parse HEAD)" == "$1" ]] || fail "Submodule HEAD differs from snapshot: $SOURCE"
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
check_bundle() {
    local kind=$1 commit verify=false depth
    bundle_paths "$kind"; check_snapshot "$MANIFEST" "$CONTENT" "$kind"
    commit=$(meta "$MANIFEST" commit)
    if [[ "$STORAGE" == submodule && -e "$SOURCE/.git" ]]; then clean_submodule "$commit"; verify=true
    elif [[ "$STORAGE" == cache && -d "$SOURCE" ]] && GIT_NO_LAZY_FETCH=1 git -C "$SOURCE" cat-file -e "$commit^{commit}" 2>/dev/null; then verify=true; fi
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
    setting "$kind" root > "$base/roots"
    local root_pattern reference_root
    : > "$base/declared-roots"
    if [[ -n "$MODULE_KEY" ]]; then
        git config -f "$ROOT/.gitmodules" --get-all "$MODULE_KEY.referenceRoot" > "$base/declared-roots" || true
    fi
    if [[ -s "$base/declared-roots" ]]; then
        cp "$base/declared-roots" "$base/roots"
    else
        while IFS= read -r root_pattern; do
            awk -F '\t' -v pattern="$root_pattern" '$2 ~ pattern {print $2}' "$base/tree.tsv" > "$base/matched-roots"
            [[ -s "$base/matched-roots" ]] || fail "No roots match $kind: $root_pattern"
            cat "$base/matched-roots" >> "$base/roots"
        done < <(setting "$kind" root_pattern)
    fi
    printf '%s\n' "$LICENSE_FILE" >> "$base/roots"
    sort -u "$base/roots" -o "$base/roots"
    : > "$base/queue"
    while IFS= read -r reference_root; do
        safe_path "$reference_root"
        awk -F '\t' -v path="${reference_root%/}" '$2==path || index($2,path "/")==1 {print $2; found=1} END {exit !found}' "$base/tree.tsv" >> "$base/queue" || fail "Reference root missing: $reference_root"
    done < "$base/roots"
    sort -u "$base/queue" -o "$base/queue"
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
            name=$path; [[ "$LAYOUT" != flat ]] || name=$(basename "$path")
            [[ ! -e "$dest/files/$name" ]] || fail "Duplicate output path: $name"
            (( count += 1 )); [[ $count -le 512 ]] || fail 'Bundle exceeds 512 files'
            bytes=$(git -C "$SOURCE" cat-file -s "$commit:$path")
            [[ $bytes -le 4194304 ]] || fail "File exceeds 4 MiB: $path"
            mkdir -p "$(dirname "$dest/files/$name")"
            git -C "$SOURCE" show "$commit:$path" > "$dest/files/$name"
            printf '%s\n' "$path" >> "$base/seen"
            printf 'file\t%s\t%s\t%s\n' "$name" "$(sha "$dest/files/$name")" "$path" >> "$base/records"
            case "$path" in *.md|*.mdx|*.html|*.txt)
                text_tool links "$dest/files/$name" | sort -u > "$base/links"
                REFERENCE_PREFIX="$REFERENCE_PREFIX" URL_PREFIX="$URL_PREFIX" HTML_SUFFIX="$HTML_SUFFIX" SOURCE_PATH=$path LEVEL=$level DEPTH=$depth text_tool resolve "$base/tree.tsv" "$base/links" >> "$base/level" ;;
            esac
        done < "$base/queue"
        cat "$base/level" >> "$base/references"
        awk -F '\t' '$5=="bundled" {print $4}' "$base/level" | sort -u > "$base/queue"
        (( level += 1 ))
    done
    LAYOUT="$LAYOUT" text_tool finalize "$base/seen" "$base/references" >> "$base/records"
    local license_name license_metadata scope
    license_name=$LICENSE_FILE; [[ "$LAYOUT" != flat ]] || license_name=$(basename "$LICENSE_FILE")
    case "$LICENSE_KIND" in
        MIT) grep -Eq 'MIT License|Permission is hereby granted' "$dest/files/$license_name" ;;
        BSD) grep -Eq 'Redistribution and use in source and binary forms' "$dest/files/$license_name" ;;
        Apache) grep -Eq 'Apache License' "$dest/files/$license_name" ;;
    esac || fail "License changed: $kind"
    revision=$(setting "$kind" revision)
    [[ -z "$revision" ]] || printf 'meta\trevision\t%s\n' "$revision" >> "$base/records"
    license_metadata=$(setting "$kind" license_metadata); scope=$(setting "$kind" scope)
    [[ -z "$license_metadata" ]] || printf 'meta\tlicense\t%s\n' "$LICENSE_KIND" >> "$base/records"
    [[ -z "$scope" ]] || printf 'meta\tscope\t%s\n' "$scope" >> "$base/records"
    sort "$base/records" > "$dest/SOURCE.tsv"
    text_tool validate "$dest/SOURCE.tsv"
    manifest_json "$kind" "$dest/SOURCE.tsv" "$dest/SOURCE.json"
}
backup_bundle() {
    local kind=$1 name
    bundle_paths "$kind"
    if [[ "$(setting "$kind" initial)" == yes ]]; then
        mkdir -p "$WORK/before/$kind/files"
        printf 'meta\tcommit\tuninitialized\n' > "$WORK/before/$kind/SOURCE.tsv"
        : > "$WORK/before/$kind/names"
        return
    fi
    check_snapshot "$MANIFEST" "$CONTENT" "$kind"
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
    if [[ "$(setting "$kind" initial)" == yes && ! -e "$MANIFEST" ]]; then
        [[ ! -e "$CONTENT" ]] || fail "Initial reference output changed: $CONTENT"
    else
        cmp -s "$MANIFEST" "$WORK/before/$kind/SOURCE.tsv" || fail "Snapshot changed during preparation: $kind"
        check_snapshot "$MANIFEST" "$CONTENT" "$kind"
    fi
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
    local url code resolved availability exit_code file number=0
    : > "$WORK/api.tsv"
    : > "$WORK/api-raw"
    while IFS= read -r file; do
        text_tool links "$file" >> "$WORK/api-raw"
    done < <(find "$ROOT/skills" -type f -path '*/references/*' \( -name '*official*.md' -o -name '*api*.md' \) ! -path '*/upstream/*' | sort)
    awk '/^https:\/\// {print}' "$WORK/api-raw" | sort -u > "$WORK/api-urls"
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
    while IFS= read -r kind; do
        printf 'source\t%s\t%s\t%s\n' "$kind" "$(meta "$WORK/before/$kind/SOURCE.tsv" commit)" "$(meta "$WORK/candidate/$kind/SOURCE.tsv" commit)" >> "$WORK/report.tsv"
        awk -F '\t' -v kind="$kind" '
            FNR==NR {if($1=="file") old[$2]=$3; next}
            $1=="file" {seen[$2]=1; if(!($2 in old)) print "added\t" kind "\t" $2; else if(old[$2]!=$3) print "changed\t" kind "\t" $2}
            END {for(p in old) if(!(p in seen)) print "removed\t" kind "\t" p}
        ' "$WORK/before/$kind/SOURCE.tsv" "$WORK/candidate/$kind/SOURCE.tsv" | sort >> "$WORK/report.tsv"
        awk -F '\t' -v kind="$kind" '$1=="ref" {n[$5]++} END {for(s in n) print "references\t" kind "\t" s "\t" n[s]}' "$WORK/candidate/$kind/SOURCE.tsv" | sort >> "$WORK/report.tsv"
    done < "$WORK/sources"
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
       [--ref SOURCE REF] [--reference-depth 0..3]
Default: discover SOURCE.tsv snapshots and matching .gitmodules; update their refs.
--check: offline snapshot hashes and bounded reference validation.
--dry-run: fetch and validate candidates without changing distributed files.
--ref: override one source's configured ref/tag policy for this invocation.
Legacy --three-ref / --comfy-ref remain aliases for existing users.
Requires Bash 3.2+, Git, awk, grep, sed, curl, common Unix utilities and
sha256sum or shasum. Windows: standard Git Bash. No jq/Python/Node runtime.
USAGE
}
main() {
    local action=update depth=1 arg kind commit old_commit latest override_id override_ref
    local overrides=()
    export GIT_TERMINAL_PROMPT=0
    export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=15}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h) usage; return ;;
            --check|--dry-run) [[ "$action" == update ]] || fail 'Choose one mode'; action=${1#--}; shift ;;
            --ref)
                [[ $# -ge 3 ]] || fail 'Missing SOURCE REF for --ref'
                overrides+=("$2" "$3"); shift 3 ;;
            --three-ref|--comfy-ref)
                [[ $# -ge 2 ]] || fail "Missing value: $1"
                if [[ "$1" == --three-ref ]]; then overrides+=(threejs "$2"); else overrides+=(comfy-skills "$2"); fi
                shift 2 ;;
            --reference-depth) [[ $# -ge 2 ]] || fail 'Missing depth'; depth=$2; shift 2 ;;
            *) fail "Unknown argument: $1" ;;
        esac
    done
    [[ "$depth" =~ ^[0-3]$ ]] || fail 'Reference depth must be 0..3'
    for arg in git awk grep sed curl sort find comm cmp mktemp; do command -v "$arg" >/dev/null 2>&1 || fail "Required tool not found: $arg"; done
    command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || fail 'Install sha256sum or shasum'
    mkdir -p "$CACHE"
    WORK=$(mktemp -d "$CACHE/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
    trap finish EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
    if [[ "$action" != check ]]; then
        mkdir "$CACHE/update.lock.d" 2>/dev/null || fail 'Another update holds tmp/upstreams/update.lock.d; confirm it has stopped before removing a stale lock'
        LOCK="$CACHE/update.lock.d"
        [[ ! -e "$CACHE/update.lock" ]] || fail 'Previous updater lock exists; confirm that process has stopped'
    fi
    if [[ "$action" != check && -f "$ROOT/.gitmodules" ]]; then
        while IFS= read -r arg; do
            safe_path "$arg"
            [[ -e "$ROOT/$arg/.git" ]] || git -C "$ROOT" submodule update --init -- "$arg"
        done < <(git config -f "$ROOT/.gitmodules" --get-regexp '^submodule[.].*[.]path$' | sed 's/^[^ ]* //' || true)
    fi
    discover_upstreams
    while [[ ${#overrides[@]} -gt 0 ]]; do
        override_id=${overrides[0]}; override_ref=${overrides[1]}; overrides=("${overrides[@]:2}")
        grep -Fxq -- "$override_id" "$WORK/sources" || fail "Unknown source: $override_id"
        [[ "$override_ref" =~ ^[A-Za-z0-9][A-Za-z0-9_./-]*$ && "$override_ref" != *..* ]] || fail "Invalid ref: $override_ref"
        awk -F '\t' -v OFS='\t' -v id="$override_id" -v ref="$override_ref" '!($1==id && ($2=="ref" || $2=="tag_prefix")) {print} END {print id,"ref",ref}' "$CONFIG" > "$WORK/overridden.tsv"
        mv "$WORK/overridden.tsv" "$CONFIG"
    done
    if [[ "$action" == check ]]; then
        while IFS= read -r kind; do check_bundle "$kind"; done < "$WORK/sources"
        return
    fi
    while IFS= read -r kind; do
        backup_bundle "$kind"; bundle_paths "$kind"
        if [[ "$(setting "$kind" initial)" == yes ]]; then
            old_commit=$(git -C "$SOURCE" rev-parse HEAD)
        else old_commit=$(meta "$MANIFEST" commit); fi
        if [[ "$STORAGE" == submodule ]]; then
            arg=$(setting "$kind" submodule)
            [[ $(git -C "$ROOT" ls-files --stage -- "$arg") == '160000 '* ]] || fail "Not a gitlink: $arg"
            [[ -e "$SOURCE/.git" ]] || git -C "$ROOT" submodule update --init -- "$arg"
            clean_submodule "$old_commit"
        else [[ -d "$SOURCE" ]] || git init --quiet --bare "$SOURCE"; fi
        if [[ -n "$TAG_PREFIX" ]]; then
            git ls-remote --tags --refs -- "$REPO" "refs/tags/$TAG_PREFIX*" > "$WORK/tags.txt"
            latest=$(awk -v prefix="refs/tags/$TAG_PREFIX" 'index($2,prefix)==1 {n=substr($2,length(prefix)+1); if(n ~ /^[0-9]+$/) print n}' "$WORK/tags.txt" | sort -n | tail -n 1)
            [[ -n "$latest" ]] || fail "No stable numeric tag: $kind"
            REF="refs/tags/$TAG_PREFIX$latest"
        fi
        printf 'Fetch %s %s\n' "$kind" "$REF"
        git -C "$SOURCE" fetch --no-tags --depth=1 -- "$REPO" "$REF"
        commit=$(git -C "$SOURCE" rev-parse 'FETCH_HEAD^{commit}')
        if [[ -n "$(setting "$kind" revision)" && "$commit" != "$old_commit" ]]; then
            if [[ -n "$TAG_PREFIX" && "$REF" == "refs/tags/$TAG_PREFIX"* ]]; then latest=${REF#"refs/tags/$TAG_PREFIX"}
            else
                git ls-remote --tags --refs -- "$REPO" > "$WORK/revision-tags"
                latest=$(awk -v sha="$commit" '$1==sha && $2 ~ /^refs\/tags\/[A-Za-z-]*[0-9]+$/ {sub(/^refs\/tags\/[A-Za-z-]*/,"",$2); print $2; exit}' "$WORK/revision-tags")
            fi
            [[ "$latest" =~ ^[0-9]+$ ]] || fail "Cannot resolve snapshot revision: $kind"
            awk -F '\t' -v OFS='\t' -v id="$kind" -v revision="$latest" '{if($1==id && $2=="revision") $3=revision; print}' "$CONFIG" > "$WORK/revised.tsv"
            mv "$WORK/revised.tsv" "$CONFIG"
        fi
        collect_bundle "$kind" "$commit" "$depth" "$WORK/candidate/$kind"
    done < "$WORK/sources"
    check_api_links
    : > "$WORK/module-commits"
    while IFS= read -r kind; do
        preflight_bundle "$kind"; bundle_paths "$kind"
        if [[ "$STORAGE" == submodule ]]; then
            arg=$(setting "$kind" submodule); commit=$(meta "$WORK/candidate/$kind/SOURCE.tsv" commit)
            awk -F '\t' -v path="$arg" -v commit="$commit" '$1==path && $2!=commit {exit 1}' "$WORK/module-commits" || fail "Conflicting refs for submodule: $arg"
            printf '%s\t%s\n' "$arg" "$commit" >> "$WORK/module-commits"
        fi
    done < "$WORK/sources"
    PHASE=prepared; write_report
    if [[ "$action" != dry-run ]]; then
        PHASE=applying
        while IFS= read -r kind; do
            bundle_paths "$kind"
            if [[ "$(setting "$kind" initial)" == yes ]]; then
                old_commit=$(git -C "$SOURCE" rev-parse HEAD)
            else old_commit=$(meta "$MANIFEST" commit); fi
            commit=$(meta "$WORK/candidate/$kind/SOURCE.tsv" commit)
            preflight_bundle "$kind"
            if [[ "$STORAGE" == submodule ]]; then
                if [[ "$(git -C "$SOURCE" rev-parse HEAD)" == "$commit" ]]; then clean_submodule "$commit"
                else
                    clean_submodule "$old_commit"
                    git -C "$SOURCE" checkout --detach --no-overwrite-ignore "$commit"
                fi
            fi
            apply_bundle "$kind"
        done < "$WORK/sources"
        while IFS= read -r kind; do check_bundle "$kind"; done < "$WORK/sources"
        PHASE=updated; write_report
    fi
    cat "$WORK/report.tsv"
    printf 'Evidence: %s\n' "$WORK"
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
