#!/bin/bash

set -e

PublicFile=./agents.public.json

# 版本与公共字段只从 agents.public.json 读。各宿主清单由 scripts/sync_public_infos.sh 按各自格式写入。
ProductName=$(sed -n 's/^  "displayName": "\([^"]*\)".*/\1/p' "$PublicFile" | head -1)
PUBLIC_VERSION=$(sed -n 's/^  "version": "\([0-9][0-9.]*\)".*/\1/p' "$PublicFile" | head -1)
CURRENT_VERSION="v${PUBLIC_VERSION}"

NEXT_VERSION=""

OS_TYPE="Unknown"
GetOSType() {
    uNames=`uname -s`
    osName=${uNames: 0: 4}
    if [ "$osName" == "Darw" ] # Darwin
    then
        OS_TYPE="Darwin"
    elif [ "$osName" == "Linu" ] # Linux
    then
        OS_TYPE="Linux"
    elif [ "$osName" == "MING" ] # MINGW, windows, git-bash
    then
        OS_TYPE="Windows"
    else
        OS_TYPE="Unknown"
    fi
}
GetOSType

function to_run() {
    if [ -z "$1" ]; then
        baseStr=$(echo ${CURRENT_VERSION} | cut -d'.' -f1)     # Get the base version (v0)
        base=${baseStr//v/}                                       # Get the base version (0)
        major=$(echo ${CURRENT_VERSION} | cut -d'.' -f2)       # Get the major version (0)
        minor=$(echo ${CURRENT_VERSION}| cut -d'.' -f3)       # Get the minor version (1)

        minor=$((minor+1))                          # Increment the minor version
        if ((minor==1000)); then                     # Check if minor version is 100
            minor=0                                 # Reset minor version to 0
            major=$((major+1))                      # Increment major version
        fi

        if ((major==1000)); then                     # Check if major version is 100
            major=0                                 # Reset major version to 0
            base=$((base+1))                        # Increment base version
        fi

        NEXT_VERSION="v${base}.${major}.${minor}"
        return 0
    elif [ "$1" == "custom" ]; then
        echo "============================ ${ProductName} ============================"
        echo "  1、release [-${ProductName}-]"
        echo "  current version [-${CURRENT_VERSION}-]"
        echo "======================================================================"
        read -p "$(echo -e "please input version string [example；v0.0.1]")" inputString
        if [[ "$inputString" =~ ^v.* ]]; then
            NEXT_VERSION=${inputString}
        else
            NEXT_VERSION=v${inputString}
        fi
        return 0
    else
        return 1
    fi
}

function get_pre_del_version_no {
    local v_str=$1
    baseStr=$(echo $v_str | cut -d'.' -f1)     # Get the base version (v0)
    base=${baseStr//v/}                                       # Get the base version (0)
    major=$(echo $v_str | cut -d'.' -f2)       # Get the major version (0)
    minor=$(echo $v_str | cut -d'.' -f3)       # Get the minor version (1)

    if ((minor>0)); then                      # Check if minor version is more than 0
        minor=$((minor-1))                     # Decrement the minor version
    else
        minor=999                              # Reset minor version to 99
        if ((major>0)); then                   # Check if major version is more than 0
            major=$((major-1))                 # Decrement major version
        else
            major=999                           # Reset major version to 99
            if ((base>0)); then                # Check if base version is more than 0
                base=$((base-1))               # Decrement base version
            else
                echo "Error: Version cannot be decremented."
                exit 1
            fi
        fi
    fi

    pre_v_no="${base}.${major}.${minor}"
    echo $pre_v_no
}

function git_handle_ready() {
    bash scripts/update_upstreams.sh

    echo "Current Version With ${CURRENT_VERSION}"
    echo "Next Version    With ${NEXT_VERSION}"

    local plain_version="${NEXT_VERSION#v}"

    sed -i -e "s/^  \"version\": \"[0-9.]*\"/  \"version\": \"${plain_version}\"/" "$PublicFile"
    if [[ $OS_TYPE == "Darwin" ]]; then
        rm -f "${PublicFile}-e" 2>/dev/null || true
    fi
    bash scripts/sync_public_infos.sh
}

function find_prev_release_commit() {
    git log --fixed-strings --grep='Release:--:' --format='%H' -n 1 HEAD || true
}

function gen_changelog_if_possible() {
    local del_version_no="$1"
    local out_dir out_file prev_release_sha range_end range
    out_dir="changelog"
    mkdir -p "${out_dir}"

    out_file="${out_dir}/${NEXT_VERSION}.md"

    prev_release_sha="$(find_prev_release_commit)"
    range_end="HEAD"

    if [ -z "${prev_release_sha}" ]; then
        # 没有历史 release marker：从仓库首提交到当前 HEAD
        prev_release_sha="$(git rev-list --max-parents=0 HEAD | tail -n 1)"
        range="${prev_release_sha}..${range_end}"
        echo "[changelog] no previous Release marker found, use range ${range}"
        local prev_label="root(${prev_release_sha:0:7})"
    else
        range="${prev_release_sha}..${range_end}"
        echo "[changelog] previous Release marker: ${prev_release_sha}"
        local prev_label="${prev_release_sha:0:7}"
    fi

    local commit_count
    commit_count="$(git rev-list --count "${range}" 2>/dev/null || echo 0)"

    {
        echo "## ${NEXT_VERSION} ChangeLog"
        echo
        echo "- Release:--: ${NEXT_VERSION}_$(date -u +"%Y-%m-%d_%H:%M:%S")_UTC"
        echo "- Range: ${range}"
        echo "- Commits: ${commit_count}"
        echo

        echo "###  commit infos"
        echo
        if [[ "${commit_count}" == "0" ]]; then
            echo "- (no commits between releases)"
            echo "- (no file changes)"
        else
            # 概览（总增删行/文件数）
            # 例如： " 3 files changed, 10 insertions(+), 2 deletions(-)"
            local shortstat
            shortstat="$(git diff --shortstat "${range}" 2>/dev/null || true)"
            if [ -n "${shortstat}" ]; then
                echo "- ${shortstat}"
            else
                echo "- (no file changes)"
            fi
            echo
            # 文件级统计（不输出具体 diff 内容）
            echo '```'
            git diff --stat "${range}" 2>/dev/null || true
            echo '```'
        fi
        echo

        echo "### commit messages"
        echo
        if [[ "${commit_count}" == "0" ]]; then
            echo "- (no commits between releases)"
        else
            git log --reverse --date=short --pretty=format:"- %ad %h %s" "${range}" || true
        fi
        echo
    } > "${out_file}"

    echo "[changelog] wrote ${out_file}"

    if [ -n "${del_version_no}" ]; then
        local pre_file="${out_dir}/v${del_version_no}.md"
        if [ -f "${pre_file}" ]; then
            if git ls-files --error-unmatch "${pre_file}" >/dev/null 2>&1; then
                git rm -f "${pre_file}"
            else
                rm -f "${pre_file}" 2>/dev/null || true
            fi
            echo "[changelog] removed ${pre_file}"
        fi
    fi
}

# run_release_step 记录当前步骤再执行；&& 链中途失败不会触发 set -e，靠它指出停在哪一步。
function run_release_step() {
    last_release_step="$*"
    "$@"
}

function git_handle_push() {
    local current_version_no=${CURRENT_VERSION//v/}
    local next_version_no=${NEXT_VERSION//v/}
    local pre_del_version_no=$(get_pre_del_version_no "$current_version_no")
    echo "Pre Del Version With v"${pre_del_version_no}

    # Standalone health gate (B): refuse to cut an aggregation tag if any
    # submodule fails to build/tidy cleanly without go.work support.
    if [ -x ./scripts/check_standalone.sh ]; then
        ./scripts/check_standalone.sh
    fi

    echo current_version_no: $current_version_no
    echo next_version_no: $next_version_no
    echo pre_del_version_no: $pre_del_version_no

    if ! { run_release_step gen_changelog_if_possible "${pre_del_version_no}" \
    && run_release_step git add . \
    && run_release_step git commit -m "Release:--: v${next_version_no}_$(date -u +"%Y-%m-%d_%H:%M:%S")"_"UTC" \
    && run_release_step git tag v${next_version_no} \
    && run_release_step git tag -f latest v${next_version_no}; }; then
        echo "[git_tag] ERROR: release v${next_version_no} stopped before push at: ${last_release_step}" >&2
        echo "[git_tag] nothing was pushed; inspect git status / git log -1 / git tag, fix the cause, then rerun." >&2
        exit 1
    fi

    local push_failed_remotes=""
    for remote in $(git remote)
    do
        echo "Pushing to ${remote}..."
        if ! { run_release_step git push --delete ${remote} latest \
        && run_release_step git push ${remote} \
        && run_release_step git push ${remote} latest \
        && run_release_step git push ${remote} v${next_version_no}; }; then
            echo "[git_tag] ERROR: push to ${remote} stopped at: ${last_release_step}" >&2
            push_failed_remotes="${push_failed_remotes} ${remote}"
        fi
    done
    git tag -d v${pre_del_version_no}

    if [ -n "${push_failed_remotes}" ]; then
        echo "[git_tag] ERROR: release v${next_version_no} is committed and tagged locally, but push failed for:${push_failed_remotes}" >&2
        echo "[git_tag] retry each failed remote in order, starting from the step that failed:" >&2
        echo "[git_tag]   git push --delete <remote> latest   (skip when the remote has no latest tag)" >&2
        echo "[git_tag]   git push <remote>" >&2
        echo "[git_tag]   git push <remote> latest" >&2
        echo "[git_tag]   git push <remote> v${next_version_no}" >&2
        echo "[git_tag] verify: git ls-remote <remote> refs/heads/main refs/tags/latest refs/tags/v${next_version_no}" >&2
        exit 1
    fi
}

handle_input(){
    if [[ $1 == "-get_pre_del_tag_name" ]]; then
        pre_tag=$(get_pre_del_version_no "${CURRENT_VERSION}")
        echo "Pre Del Tag With " "$pre_tag"
    elif [ -z "$1" ] || [ "$1" == "auto" ]; then

        if to_run "$1"; then
            git_handle_ready
            git_handle_push
            echo "Complated"
        else
            echo "Invalid argument normal"
        fi
    else
        echo "Invalid argument"
    fi
}

handle_input "$@"
