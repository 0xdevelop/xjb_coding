#!/bin/bash
# 把 agents.public.json 的公共字段按各宿主清单自己的键写回去。
# 只做精确替换；目标键不在或匹配数不是 1 则失败。不覆盖宿主专属块。

set -euo pipefail

cd "$(dirname "$0")/.."

PublicFile=./agents.public.json

read_public() {
    local key="$1"
    local val
    val=$(sed -n "s/^  \"${key}\": \"\\([^\"]*\\)\".*/\\1/p" "$PublicFile" | head -1)
    if [ -z "$val" ]; then
        echo "sync_public_infos: missing ${key} in ${PublicFile}" >&2
        exit 1
    fi
    printf '%s' "$val"
}

replace_once() {
    local file="$1"
    local grepe="$2"
    local seds="$3"
    local n
    if [ ! -f "$file" ]; then
        echo "sync_public_infos: missing file ${file}" >&2
        exit 1
    fi
    n=$(grep -cE "$grepe" "$file" || true)
    if [ "$n" != "1" ]; then
        echo "sync_public_infos: want 1 match of ${grepe} in ${file}, got ${n}" >&2
        exit 1
    fi
    sed -i -e "$seds" "$file"
}

Name=$(read_public name)
DisplayName=$(read_public displayName)
Version=$(read_public version)
Author=$(read_public author)
Repository=$(read_public repository)
McpDefaultUrl=$(read_public mcpDefaultUrl)

# Claude：name / displayName / author.name / mcp_url.default。不写 version。
replace_once ./.claude-plugin/plugin.json \
    '^  "name": "[^"]*"' \
    "s#^  \"name\": \"[^\"]*\"#  \"name\": \"${Name}\"#"
replace_once ./.claude-plugin/plugin.json \
    '^  "displayName": "[^"]*"' \
    "s#^  \"displayName\": \"[^\"]*\"#  \"displayName\": \"${DisplayName}\"#"
replace_once ./.claude-plugin/plugin.json \
    '^    "name": "[^"]*"' \
    "s#^    \"name\": \"[^\"]*\"#    \"name\": \"${Author}\"#"
replace_once ./.claude-plugin/plugin.json \
    '^      "default": "http[^"]*"' \
    "s#^      \"default\": \"http[^\"]*\"#      \"default\": \"${McpDefaultUrl}\"#"
if grep -q '"version"' ./.claude-plugin/plugin.json; then
    echo "sync_public_infos: Claude Git marketplace 清单不得写 version" >&2
    exit 1
fi

# Codex：name / version / author.name / interface.displayName / developerName / websiteURL
replace_once ./.codex-plugin/plugin.json \
    '^  "name": "[^"]*"' \
    "s#^  \"name\": \"[^\"]*\"#  \"name\": \"${Name}\"#"
replace_once ./.codex-plugin/plugin.json \
    '^  "version": "[^"]*"' \
    "s#^  \"version\": \"[^\"]*\"#  \"version\": \"${Version}\"#"
replace_once ./.codex-plugin/plugin.json \
    '^    "name": "[^"]*"' \
    "s#^    \"name\": \"[^\"]*\"#    \"name\": \"${Author}\"#"
replace_once ./.codex-plugin/plugin.json \
    '^    "displayName": "[^"]*"' \
    "s#^    \"displayName\": \"[^\"]*\"#    \"displayName\": \"${DisplayName}\"#"
replace_once ./.codex-plugin/plugin.json \
    '^    "developerName": "[^"]*"' \
    "s#^    \"developerName\": \"[^\"]*\"#    \"developerName\": \"${Author}\"#"
replace_once ./.codex-plugin/plugin.json \
    '^    "websiteURL": "[^"]*"' \
    "s#^    \"websiteURL\": \"[^\"]*\"#    \"websiteURL\": \"${Repository}\"#"

# Cursor：name / version / author.name / XJB_CODE_MCP_URL.default
replace_once ./.cursor-plugin/plugin.json \
    '^  "name": "[^"]*"' \
    "s#^  \"name\": \"[^\"]*\"#  \"name\": \"${Name}\"#"
replace_once ./.cursor-plugin/plugin.json \
    '^  "version": "[^"]*"' \
    "s#^  \"version\": \"[^\"]*\"#  \"version\": \"${Version}\"#"
replace_once ./.cursor-plugin/plugin.json \
    '^    "name": "[^"]*"' \
    "s#^    \"name\": \"[^\"]*\"#    \"name\": \"${Author}\"#"
replace_once ./.cursor-plugin/plugin.json \
    '^        "default": "http[^"]*"' \
    "s#^        \"default\": \"http[^\"]*\"#        \"default\": \"${McpDefaultUrl}\"#"

# Orca：id=name，清单 name=displayName，version / author.name
replace_once ./orca-plugin.json \
    '^  "id": "[^"]*"' \
    "s#^  \"id\": \"[^\"]*\"#  \"id\": \"${Name}\"#"
replace_once ./orca-plugin.json \
    '^  "name": "[^"]*"' \
    "s#^  \"name\": \"[^\"]*\"#  \"name\": \"${DisplayName}\"#"
replace_once ./orca-plugin.json \
    '^  "version": "[^"]*"' \
    "s#^  \"version\": \"[^\"]*\"#  \"version\": \"${Version}\"#"
replace_once ./orca-plugin.json \
    '^  "author": \{ "name": "[^"]*" \}' \
    "s#^  \"author\": { \"name\": \"[^\"]*\" }#  \"author\": { \"name\": \"${Author}\" }#"

# Hermes / Agent Plugins v1：根级声明式清单，不自动连接 MCP。
replace_once ./plugin.json \
    '^  "name": "[^"]*"' \
    "s#^  \"name\": \"[^\"]*\"#  \"name\": \"${Name}\"#"
replace_once ./plugin.json \
    '^  "version": "[^"]*"' \
    "s#^  \"version\": \"[^\"]*\"#  \"version\": \"${Version}\"#"
replace_once ./plugin.json \
    '^  "author": \{ "name": "[^"]*" \}' \
    "s#^  \"author\": { \"name\": \"[^\"]*\" }#  \"author\": { \"name\": \"${Author}\" }#"
replace_once ./plugin.json \
    '^  "repository": "[^"]*"' \
    "s#^  \"repository\": \"[^\"]*\"#  \"repository\": \"${Repository}\"#"

# 独立 Skill 入口：frontmatter 的 name / version，以及页眉 SkillName / Version
replace_once ./skills/xjb-coding/SKILL.md \
    '^name: ' \
    "s#^name: .*#name: ${Name}#"
replace_once ./skills/xjb-coding/SKILL.md \
    '^version: [0-9.]' \
    "s#^version: [0-9.]*#version: ${Version}#"
replace_once ./skills/xjb-coding/SKILL.md \
    '^> \*\*SkillName\*\*：`' \
    "s#^> \\*\\*SkillName\\*\\*：\`[^\\\`]*\`#> **SkillName**：\`${DisplayName}\`#"
replace_once ./skills/xjb-coding/SKILL.md \
    '^> \*\*Version\*\*：v[0-9.]' \
    "s#^> \\*\\*Version\\*\\*：v[0-9.]*#> **Version**：v${Version}#"

if [ -f ./skills/xjb-coding/.auto_coding/start_coding.md ]; then
    replace_once ./skills/xjb-coding/.auto_coding/start_coding.md \
        '^> \*\*版本\*\*：v[0-9.]' \
        "s#^> \\*\\*版本\\*\\*：v[0-9.]*#> **版本**：v${Version}#"
fi

# Codex 插件 MCP 不能写变量，默认地址写字面量
replace_once ./.mcp.codex.json \
    '^      "url": "[^"]*"' \
    "s#^      \"url\": \"[^\"]*\"#      \"url\": \"${McpDefaultUrl}\"#"

if [ "$(uname -s)" = "Darwin" ]; then
    rm -f \
        ./.claude-plugin/plugin.json-e \
        ./.codex-plugin/plugin.json-e \
        ./.cursor-plugin/plugin.json-e \
        ./orca-plugin.json-e \
        ./plugin.json-e \
        ./skills/xjb-coding/SKILL.md-e \
        ./skills/xjb-coding/.auto_coding/start_coding.md-e \
        ./.mcp.codex.json-e \
        2>/dev/null || true
fi

echo "sync_public_infos: wrote ${DisplayName} ${Version} from ${PublicFile}"
