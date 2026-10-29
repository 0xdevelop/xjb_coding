#!/usr/bin/env bash
# Check delegation prerequisites without installing tools or creating sessions.
set -eu
missing=0

if ! command -v node >/dev/null 2>&1; then
    printf 'Cursor 委派先决：不满足，缺少 Node.js ≥ 22.13。本次不派发；主 agent 继续当前实现，不等待用户回复。安装：https://nodejs.org/en/download\n'
    exit 2
fi
if ! node -e 'const [major, minor] = process.versions.node.split(".").map(Number); process.exit(major > 22 || major === 22 && minor >= 13 ? 0 : 1)' 2>/dev/null; then
    printf 'Cursor 委派先决：不满足，Node.js 需 ≥ 22.13。本次不派发；主 agent 继续当前实现，不等待用户回复。更新：https://nodejs.org/en/download\n'
    exit 2
fi
printf 'Node.js：%s\n' "$(node --version)"

# Arguments are fixed version/help/status tokens; never pass task text here.
cursor_check_command() {
    node -e '
const { spawnSync } = require("node:child_process");
const [command, ...args] = process.argv.slice(1);
const windows = process.platform === "win32";
const result = spawnSync(windows ? "cmd.exe" : command,
    windows ? ["/d", "/s", "/c", [command, ...args].join(" ")] : args,
    { encoding: "utf8", timeout: 8000, maxBuffer: 262144, windowsHide: true });
if (result.error || result.status !== 0) process.exit(1);
process.stdout.write(result.stdout);
' "$@" 2>/dev/null
}

if ! command -v acpx >/dev/null 2>&1; then
    printf 'acpx：未找到。建议按既有包管理方式安装；官方命令：npm install --global acpx@latest && acpx --version\n'
    missing=1
elif acpx_version=$(cursor_check_command acpx --version) && [[ $acpx_version =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([._+-][[:alnum:]._-]+)?$ ]]; then
    printf 'acpx：%s\n' "$acpx_version"
    if acpx_help=$(cursor_check_command acpx cursor --help) && [[ $acpx_help == *'Usage: acpx cursor '* ]]; then
        printf 'acpx Cursor 子命令：已识别\n'
    else
        printf 'acpx Cursor 子命令：未核实，检查本机版本与官方文档：https://github.com/openclaw/acpx\n'
        missing=1
    fi
else
    printf 'acpx：版本命令失败、超时或格式无法识别；保留已有安装并检查。\n'
    missing=1
fi

cursor_cli=''
if command -v cursor-agent >/dev/null 2>&1; then
    cursor_cli=cursor-agent
elif command -v agent >/dev/null 2>&1; then
    if cursor_help=$(cursor_check_command agent --help) && [[ $cursor_help == *'Start the Cursor Agent'* ]]; then
        cursor_cli=agent
        printf 'Cursor CLI：仅检测到 agent 别名；acpx 调用需加 --agent '\''agent acp'\''。\n'
    fi
fi

if [[ -z $cursor_cli ]]; then
    printf 'Cursor CLI：未找到可确认的入口。安装指引：https://cursor.com/docs/cli/installation\n'
    missing=1
else
    if cursor_version=$(cursor_check_command "$cursor_cli" --version) && [[ $cursor_version =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([._+-][[:alnum:]._-]+)?$ ]]; then
        printf 'Cursor CLI：%s（%s）\n' "$cursor_version" "$cursor_cli"
    else
        printf 'Cursor CLI：版本命令失败、超时或格式无法识别。\n'
        missing=1
    fi
    if cursor_acp=$(cursor_check_command "$cursor_cli" acp --help) && [[ $cursor_acp == *'Usage: agent acp '* && $cursor_acp == *'ACP'* ]]; then
        printf 'Cursor ACP 入口：已识别，尚未握手\n'
    else
        printf 'Cursor ACP 入口：未核实，检查当前 CLI 版本：https://cursor.com/docs/cli/acp\n'
        missing=1
    fi
    if cursor_auth=$(cursor_check_command "$cursor_cli" status --format json); then
        if cursor_auth_state=$(printf '%s' "$cursor_auth" | node -e '
let text = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => text += chunk);
process.stdin.on("end", () => {
    try {
        const status = JSON.parse(text);
        if (typeof status.isAuthenticated !== "boolean") process.exit(1);
        process.stdout.write(status.isAuthenticated ? "authenticated" : "unauthenticated");
    } catch { process.exit(1); }
});' 2>/dev/null); then
            if [[ $cursor_auth_state == authenticated ]]; then
                printf 'Cursor 认证：CLI 报告已认证\n'
            else
                printf 'Cursor 认证：CLI 报告未登录。建议用户在实际执行机器运行：%s login\n' "$cursor_cli"
                missing=1
            fi
        else
            printf 'Cursor 认证：状态格式无法识别，认证未核实；未输出原始响应。\n'
            missing=1
        fi
    else
        printf 'Cursor 认证：状态命令失败或超时，认证未核实。\n'
        missing=1
    fi
fi

if [[ $missing != 0 ]]; then
    printf 'Cursor 委派先决：不满足或未核实。已提醒，本次不派发；主 agent 继续当前实现，不等待用户回复。\n'
    exit 2
fi
printf 'Cursor 委派先决：检查通过。已提醒；接下来按任务 brief 派发，不等待用户回复。\n'
