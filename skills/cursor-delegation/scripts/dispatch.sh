#!/usr/bin/env bash
# Companion: run check_tools.sh, then one acpx Cursor session. The skill owns delegation.
set -euo pipefail

ROOT=""
TASK=""
SESSION=""
WRITE=0
POLICY=""
INIT_TIMEOUT=30
TASK_TIMEOUT=600

usage() {
    printf '用法: dispatch.sh --cwd <repo> --task <brief.md> --session <name> [--write --permission-policy <file>] [--init-timeout <seconds>] [--timeout <seconds>]\n' >&2
    exit 1
}

cursor_absolute_path() {
    local cursor_path=$1
    case "$cursor_path" in
        [A-Za-z]:[\\/]*) printf '%s\n' "${cursor_path//\\//}" ;;
        /*) printf '%s\n' "$cursor_path" ;;
        *) printf '%s/%s\n' "$PWD" "$cursor_path" ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cwd)
            ROOT="${2:-}"; shift 2 ;;
        --task)
            TASK="${2:-}"; shift 2 ;;
        --session)
            SESSION="${2:-}"; shift 2 ;;
        --write)
            WRITE=1; shift ;;
        --permission-policy)
            POLICY="${2:-}"; shift 2 ;;
        --init-timeout)
            INIT_TIMEOUT="${2:-}"; shift 2 ;;
        --timeout)
            TASK_TIMEOUT="${2:-}"; shift 2 ;;
        -h|--help)
            usage ;;
        *)
            usage ;;
    esac
done

[[ -n $ROOT && -n $TASK && -n $SESSION ]] || usage
for seconds in "$INIT_TIMEOUT" "$TASK_TIMEOUT"; do
    [[ $seconds =~ ^[0-9]+([.][0-9]+)?$ && $seconds == *[1-9]* ]] || usage
done
ROOT="$(cursor_absolute_path "$ROOT")"
[[ -d $ROOT ]] || { printf 'cwd 不是目录: %s\n' "$ROOT" >&2; exit 1; }

TASK="$(cursor_absolute_path "$TASK")"
[[ -f $TASK ]] || { printf '任务 brief 不存在: %s\n' "$TASK" >&2; exit 1; }
if [[ $WRITE -eq 1 && -z $POLICY ]]; then
    printf 'Cursor 委派：写任务缺少已确认的 --permission-policy 文件，本次不派发；主 agent 继续其他工作，不等待用户回复。\n'
    exit 2
fi
if [[ -n $POLICY ]]; then
    [[ $WRITE -eq 1 ]] || usage
    POLICY="$(cursor_absolute_path "$POLICY")"
    [[ -f $POLICY && -r $POLICY ]] || { printf '权限策略文件不可读，本次不派发: %s\n' "$POLICY" >&2; exit 2; }
fi

ROOT="$(cd "$ROOT" && pwd)"
src="$(cursor_absolute_path "${BASH_SOURCE[0]}")"
SCRIPT_DIR="${src%/*}"
if ! "${BASH:-bash}" "$SCRIPT_DIR/check_tools.sh"; then
    printf 'Cursor 委派：先决不满足，本次不派发；主 agent 自己做这一片，不等待用户回复。\n'
    exit 2
fi

AGENT_FLAG=()
if ! command -v cursor-agent >/dev/null 2>&1 && command -v agent >/dev/null 2>&1; then
    AGENT_FLAG=(--agent 'agent acp')
fi

PERMS=(--approve-reads --non-interactive-permissions deny)
if [[ $WRITE -eq 1 ]]; then
    if ! node -e '
const fs = require("node:fs");
try {
    const policy = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    if (!policy || Array.isArray(policy) || typeof policy !== "object" ||
        policy.defaultAction === "approve" || policy.autoApprove?.some(rule => rule.trim() === "*")) process.exit(1);
} catch { process.exit(1); }
' "$POLICY" 2>/dev/null; then
        printf 'Cursor 委派：权限策略无效或包含全量批准，本次不派发；主 agent 沿原授权处理，不等待用户回复。\n'
        exit 2
    fi
    PERMS=(--approve-reads --non-interactive-permissions fail --permission-policy "$POLICY")
fi

cursor_recovery_notice() {
    printf 'Cursor 委派：%s失败（退出码 %s）。保留原会话；先核对会话、进程与 git diff，未确认停止前不重发、不同时修改该切片。\n' "$1" "$2" >&2
    printf '查询：' >&2
    printf '%q ' acpx --cwd "$ROOT" ${AGENT_FLAG[@]+"${AGENT_FLAG[@]}"} cursor status -s "$SESSION" >&2
    printf '\n必要时取消：' >&2
    printf '%q ' acpx --cwd "$ROOT" ${AGENT_FLAG[@]+"${AGENT_FLAG[@]}"} cursor cancel -s "$SESSION" >&2
    printf '\n主 agent 继续其他工作，不等待用户回复。\n' >&2
}

printf 'Cursor 委派：先决已过，正在派发会话 %s。\n' "$SESSION"
if acpx --cwd "$ROOT" --auth-policy fail --timeout "$INIT_TIMEOUT" --format text \
    "${PERMS[@]}" ${AGENT_FLAG[@]+"${AGENT_FLAG[@]}"} cursor sessions ensure -s "$SESSION" </dev/null; then
    :
else
    result=$?
    printf 'Cursor 委派：本次 brief 尚未发送。\n' >&2
    cursor_recovery_notice '创建或恢复会话' "$result"
    exit "$result"
fi
if acpx --cwd "$ROOT" --auth-policy fail --timeout "$TASK_TIMEOUT" --format text \
    "${PERMS[@]}" ${AGENT_FLAG[@]+"${AGENT_FLAG[@]}"} cursor -s "$SESSION" -f "$TASK" </dev/null; then
    :
else
    result=$?
    cursor_recovery_notice '任务调用' "$result"
    exit "$result"
fi
printf 'Cursor 委派：会话返回。主 agent 必须核对 git diff 与该切片验证，不以会话成功文案代替验收。\n'
