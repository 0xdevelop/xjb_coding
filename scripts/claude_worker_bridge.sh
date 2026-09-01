#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/claude_worker_bridge.sh --cwd <repo> --task <task.md> [--mode tmux|exec|print] [--session <tmux-name>]

Purpose:
  Run Claude Code as a bounded worker from a written task file, with project cwd,
  persistent logs, and a mandatory guardrail prompt.

Modes:
  print   Print the command that would run. No Claude process is started.
  exec    Run Claude in the current terminal and tee output to log.
  tmux    Start Claude in a detached tmux session and tee output to log.

Environment overrides:
  CLAUDE_BRIDGE_CLI   Claude CLI binary. Default: claude
  CLAUDE_BRIDGE_ARGS  Claude non-interactive args. Default: -p

Examples:
  scripts/claude_worker_bridge.sh --cwd /path/to/repo --task /tmp/task.md --mode print
  scripts/claude_worker_bridge.sh --cwd /path/to/repo --task /tmp/task.md --mode tmux --session claude-p6c
USAGE
}

mode="print"
session=""
cwd=""
task=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd)
      cwd="${2:-}"; shift 2 ;;
    --task)
      task="${2:-}"; shift 2 ;;
    --mode)
      mode="${2:-}"; shift 2 ;;
    --session)
      session="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$cwd" || -z "$task" ]]; then
  echo "--cwd and --task are required" >&2
  usage >&2
  exit 2
fi
if [[ ! -d "$cwd" ]]; then
  echo "cwd not found: $cwd" >&2
  exit 2
fi
if [[ ! -f "$task" ]]; then
  echo "task file not found: $task" >&2
  exit 2
fi
case "$mode" in
  print|exec|tmux) ;;
  *) echo "invalid --mode: $mode" >&2; exit 2 ;;
esac

claude_cli="${CLAUDE_BRIDGE_CLI:-claude}"
claude_args="${CLAUDE_BRIDGE_ARGS:--p}"
if ! command -v "$claude_cli" >/dev/null 2>&1; then
  echo "Claude CLI not found: $claude_cli" >&2
  echo "Set CLAUDE_BRIDGE_CLI=/path/to/claude if needed." >&2
  exit 127
fi

repo_name="$(basename "$cwd")"
ts="$(date +%Y%m%d_%H%M%S)"
bridge_dir="$cwd/.auto_coding/claude_bridge"
mkdir -p "$bridge_dir"
run_task="$bridge_dir/task_${ts}.md"
run_prompt="$bridge_dir/prompt_${ts}.md"
run_log="$bridge_dir/run_${ts}.log"
run_cmd="$bridge_dir/run_${ts}.sh"
cp "$task" "$run_task"

cat > "$run_prompt" <<PROMPT
You are a Claude Code worker controlled by a Codex architecture reviewer.

Repository cwd:
$cwd

Hard boundaries:
- Do not change environment variables, shell profiles, global config, PATH, launch agents, system services, or login items.
- Do not install software or dependencies: no brew/apt/pip/npm/pnpm/bun/go get/go mod tidy unless explicitly stated in the task.
- Do not commit, tag, push, reset, rebase, or delete files unless explicitly stated in the task.
- Do not touch files outside the repository cwd.
- Keep changes minimal and scoped to the task.
- If requirements are ambiguous or blocked, stop and report. Do not invent architecture.
- Before finishing, report: git status --short, git diff --stat, changed files, tests run.

Task:
$(cat "$task")
PROMPT

cat > "$run_cmd" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
cd "__CWD__"
printf '== claude worker started ==\n'
printf 'cwd: %s\n' "$(pwd)"
printf 'prompt: __PROMPT__\n'
printf 'log: __LOG__\n'
printf '\n== preflight git status ==\n'
git status --short || true
printf '\n== claude output ==\n'
"__CLAUDE_CLI__" __CLAUDE_ARGS__ "$(cat "__PROMPT__")"
printf '\n== postflight git status ==\n'
git status --short || true
printf '\n== postflight diff stat ==\n'
git diff --stat || true
RUNNER

python3 - "$run_cmd" "$cwd" "$run_prompt" "$run_log" "$claude_cli" "$claude_args" <<'PY'
from pathlib import Path
import shlex, sys
path, cwd, prompt, log, cli, args = sys.argv[1:]
s = Path(path).read_text()
repls = {
    "__CWD__": cwd,
    "__PROMPT__": prompt,
    "__LOG__": log,
    "__CLAUDE_CLI__": cli,
    "__CLAUDE_ARGS__": args,
}
for k, v in repls.items():
    if k == "__CLAUDE_ARGS__":
        rendered = " ".join(shlex.quote(x) for x in shlex.split(v))
    else:
        rendered = shlex.quote(v)
    s = s.replace(k, rendered)
Path(path).write_text(s)
PY
chmod +x "$run_cmd"

printf 'bridge_dir=%s\n' "$bridge_dir"
printf 'task=%s\n' "$run_task"
printf 'prompt=%s\n' "$run_prompt"
printf 'log=%s\n' "$run_log"
printf 'cmd=%s\n' "$run_cmd"

case "$mode" in
  print)
    printf '\nRun command:\n%s 2>&1 | tee %s\n' "$run_cmd" "$run_log"
    ;;
  exec)
    "$run_cmd" 2>&1 | tee "$run_log"
    ;;
  tmux)
    if ! command -v tmux >/dev/null 2>&1; then
      echo "tmux not found. Use --mode exec or install tmux yourself." >&2
      exit 127
    fi
    if [[ -z "$session" ]]; then
      session="claude_${repo_name}_${ts}"
    fi
    tmux new-session -d -s "$session" -c "$cwd" "'$run_cmd' 2>&1 | tee '$run_log'; printf '\n[claude bridge done] log: $run_log\n'; exec \$SHELL -l"
    printf 'tmux_session=%s\n' "$session"
    printf 'attach=tmux attach -t %s\n' "$session"
    ;;
esac
