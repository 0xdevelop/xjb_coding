---
name: yeah-coding-codex
description: Codex adapter for yeah_coding. Use when the user asks to use yeah_coding in Codex, initialize yeah_coding, run controller/worker collaboration, review a worker diff, or recover a yeah_coding session.
---

# yeah_coding for Codex

This skill adapts the Claude-oriented `yeah_coding` workflow to Codex.

Use the original skill at `../yeah-coding/SKILL.md` as the canonical template
source, but follow this Codex adapter first whenever the user is using Codex.

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

- `使用 yeah_coding`
- `初始化 yeah_coding`
- `setup yeah_coding`
- `安装 yeah_coding`
- `读 .auto_coding/start_coding.md`
- `从断点续做`
- `架构 controller`
- `让 worker 执行`

## Initialization

When initializing a target project:

1. Locate the project root from the user path or current working directory.
2. Locate the source template directory at `../yeah-coding/.auto_coding/`.
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
- `.proto` semantic changes
- generated code direct edits
- Redis namespace ownership changes
- new Redis key patterns without the project key builder
- identity semantics such as `conversation_id` vs `session_id`
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

Prefer the target project's declared validation commands. If unavailable:

- Go: `go build ./...`, `go test ./...`, `gofmt -l .`
- Rust: `cargo build`, `cargo test`, `cargo fmt -- --check`
- TypeScript: project build/test scripts, then formatter check

Separate environment failures from code failures. A compile error is a code
failure until proven otherwise.

## MCP Backend

If `yeah_code` MCP tools are available, prefer daemon-backed task state:

- `task.next`
- `task.lock`
- `task.complete`
- `session.checkpoint`
- `session.restore`
- `request.approval`

If those tools are unavailable in Codex, use Codex sub-agents plus
`.auto_coding/tasks/TRACKER.md` as markdown fallback.

## Codex-Specific Notes

- Use Codex `update_plan` for visible local planning.
- Use Codex sub-agents only when the user has authorized delegation or asks for
  controller/worker operation.
- Keep the parent agent on architecture, integration, and review.
- Do not let a worker broaden scope after it starts.
- Do not keep long-running worker agents open after their task is accepted.
