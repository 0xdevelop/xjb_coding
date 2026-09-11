---
name: xjb-coding-codex
description: Codex adapter for xjb_coding. Use when the user asks to use xjb_coding in Codex, initialize xjb_coding, run controller/worker collaboration, review a worker diff, or recover a xjb_coding session.
version: 0.0.22
---

# xjb_coding for Codex

This skill adapts the host-neutral `xjb_coding` workflow to Codex.

Use the original skill at `../xjb-coding/SKILL.md` as the canonical template
source, but follow this Codex adapter first whenever the user is using Codex.

`xjb_coding` and `xjb_code` are independent projects. `xjb_coding` works by
Skills fallback by default; `xjb_code` is an optional user-owned MCP
Streamable HTTP backend. If MCP is configured and connected, use it. If not,
continue with local Skills / markdown state.

Do not add telemetry, upload repository data, or configure external services
implicitly. User code, diffs, prompts, task state, requirements, and approvals
belong to the user's local or private deployment.

## Operating Model

Codex should default to controller mode:

- keep architecture context and project red lines in the parent agent
- split implementation into bounded worker tasks
- use Codex sub-agents only for narrow implementation or exploration
- review the actual working tree before accepting worker output
- report only final status, risks, and next actions to the user

The implementation worker is not an architecture owner.

## Trigger Phrases

Use this skill when the user says any of:

- `使用 xjb_coding`
- `初始化 xjb_coding`
- `setup xjb_coding`
- `安装 xjb_coding`
- `读 .auto_coding/start_coding.md`
- `从断点续做`
- `架构 controller`
- `让 worker 执行`

## Initialization

When initializing a target project:

1. Locate the project root from the user path or current working directory.
2. Locate the source template directory at `../xjb-coding/.auto_coding/`.
3. If `<project>/.auto_coding/` exists, ask before overwriting it.
4. Copy `.auto_coding/` into the project root only when approved or absent.
5. Ensure project `.gitignore` contains `.auto_coding/`.
6. Add project tool hints only when safe:
   - `CLAUDE.md` for Claude Code
   - `.cursor/rules/` for Cursor
   - `.windsurfrules` for Windsurf
7. Add `.auto_coding/AGENT_COLLABORATION.md` if absent.

Do not overwrite project-specific requirements, task state, or architecture
notes without explicit user approval.

## Controller Startup

At the start of a controller session or after reconnect, read:

1. project `CLAUDE.md`, if present
2. `.auto_coding/start_coding.md` section 9
3. `.auto_coding/requirements/_ARCH_INVARIANTS.md`, if present
4. `.auto_coding/requirements/_ROADMAP.md`, if present
5. `.auto_coding/AGENT_COLLABORATION.md`, if present
6. `git status --short`

Then report:

- dirty state
- active task, if known
- validation blockers
- next proposed action

## Delegation Rules

Before spawning or instructing a worker, write an execution brief with:

- task goal
- owned files or modules
- files or modules out of scope
- architecture red lines
- validation commands
- required final report format

Worker tasks should normally fit within 5 files and 300 changed lines. Split
the task when that is unrealistic.

## Worker Hard Boundaries

Workers must stop and report instead of acting when a task touches:

- cross-repo writes
- version constants or release changelogs
- dependency or toolchain changes
- wire-contract semantic changes (`.proto`, API schema, event payloads)
- generated code direct edits
- storage namespace ownership changes (DB / cache key prefixes, topics, buckets)
- new storage key patterns bypassing the project's established key builder
- semantics of long-lived identity fields (user/session/entity ID meaning)
- control-flow direction for sub-agents or external agents
- tests changed only to hide an implementation failure

## Review Gate

Every worker result must be reviewed by the controller before acceptance.

Use these labels:

- `OK`: safe to proceed.
- `MUST FIX`: correctness, build, security, ownership, or contract issue.
- `RISK`: requires user architecture decision.
- `STOP`: hard boundary crossed; pause implementation.

Review the actual diff and relevant code, not just the worker summary.

## Validation

Acceptance follows the four-layer gate model in `start_coding.md` §3 — each
layer inherits the previous one; an all-green toolchain run only satisfies L1:

- L1 engineering: build / test / format / lint, no hardcoded secrets
- L2 architecture: scope respected, no contract or naming drift, no scaffolding
- L3 business: acceptance criteria checked item by item, failure paths handled
- L4 project extension: checks declared in `start_coding.md` §9, if any

Prefer the target project's declared validation commands. If unavailable:

- Go: `go build ./...`, `go test ./...`, `gofmt -l .`
- Rust: `cargo build`, `cargo test`, `cargo fmt -- --check`
- TypeScript: project build/test scripts, then formatter check

Separate environment failures from code failures. A compile error is a code
failure until proven otherwise.

## MCP Backend

If `xjb_code` MCP tools are available, prefer daemon-backed task state:

- `task.next`
- `task.lock`
- `task.complete`
- `session.checkpoint`
- `session.restore`
- `request.approval`

If those tools are unavailable in Codex, use Codex sub-agents plus
`.auto_coding/tasks/TRACKER.md` as markdown fallback.

For private or team deployments, pass `project_id` when the target project space is
known. The daemon defaults to `default` and keeps project-scoped task,
requirement, approval, and session queries isolated.

## Claude Worker Bridge

When the user explicitly wants Codex to drive Claude Code as an external worker, use the repository/plugin bridge script instead of improvising a terminal workflow.

Preferred entry from this repository checkout:

```bash
scripts/claude_worker_bridge.sh --cwd <project-root> --task <task.md> --mode print
scripts/claude_worker_bridge.sh --cwd <project-root> --task <task.md> --mode tmux --session <name>
```

Rules:

- Default to `--mode print` for first use.
- Use `--mode tmux` for long Claude Code worker tasks only after the user approves running Claude.
- Always write a bounded task file first: goal, owned files, out-of-scope files, red lines, validation commands, final report format.
- Treat the bridge as process orchestration only, not a security sandbox. Review `git status`, `git diff`, and logs before accepting work.
- Claude worker must not commit, tag, push, install dependencies, or change environment unless the task explicitly allows it.

## Codex-Specific Notes

- Use Codex `update_plan` for visible local planning.
- Use Codex sub-agents only when the user has authorized delegation or asks for
  controller/worker operation.
- Keep the parent agent on architecture, integration, and review.
- Do not let a worker broaden scope after it starts.
- Do not keep long-running worker agents open after their task is accepted.
