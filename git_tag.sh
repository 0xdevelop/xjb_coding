#!/bin/bash

set -e

VersionFile=./plugins/yeah-coding/skills/yeah-coding/SKILL.md
SyncFile=./plugins/yeah-coding/skills/yeah-coding/.auto_coding/start_coding.md
PluginJsonFile=./plugins/yeah-coding/.claude-plugin/plugin.json

# SKILL.md 顶部样式：
#   > **SkillName**：`yeah_coding`
#   > **Version**：v0.0.1
# 中文冒号「：」 + backtick 包裹 SkillName + 裸 vX.X.X 包裹 Version。
ProductName=$(grep -E '^> \*\*SkillName\*\*：' "$VersionFile" | head -1 | sed -E 's/.*`([^`]+)`.*/\1/')
CURRENT_VERSION=$(grep -E '^> \*\*Version\*\*：' "$VersionFile" | head -1 | sed -E 's/.*：(v[0-9]+\.[0-9]+\.[0-9]+).*/\1/')

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
    echo "Current Version With ${CURRENT_VERSION}"
    echo "Next Version    With ${NEXT_VERSION}"

    local plain_version="${NEXT_VERSION#v}"

    # SKILL.md：`> **Version**：vX.X.X` （中文冒号，无引号）
    sed -i -e "s/^\(> \*\*Version\*\*：\)v[0-9.]*/\1${NEXT_VERSION}/" "$VersionFile"

    # start_coding.md：`> **版本**：vX.X.X 通用版`
    if [ -f "$SyncFile" ]; then
        sed -i -e "s/^\(> \*\*版本\*\*：\)v[0-9.]*\( 通用版\)/\1${NEXT_VERSION}\2/" "$SyncFile"
    fi

    # plugin.json：`"version": "X.X.X"` —— Claude Code plugin 更新检测的字段（无 v 前缀）
    if [ -f "$PluginJsonFile" ]; then
        sed -i -e "s/\"version\": \"[0-9.]*\"/\"version\": \"${plain_version}\"/" "$PluginJsonFile"
    fi

    if [[ $OS_TYPE == "Darwin" ]]; then
        rm -f "${VersionFile}-e" "${SyncFile}-e" "${PluginJsonFile}-e" 2>/dev/null || true
    fi
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

    gen_changelog_if_possible "${pre_del_version_no}" \
    && git add . \
    && git commit -m "Release:--: v${next_version_no}_$(date -u +"%Y-%m-%d_%H:%M:%S")"_"UTC" \
    && git tag v${next_version_no} \
    && git tag -f latest v${next_version_no}

    for remote in $(git remote)
    do
        echo "Pushing to ${remote}..."
        git push --delete ${remote} latest \
        && git push ${remote} \
        && git push ${remote} latest \
        && git push ${remote} v${next_version_no}
    done
    git tag -d v${pre_del_version_no}
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
