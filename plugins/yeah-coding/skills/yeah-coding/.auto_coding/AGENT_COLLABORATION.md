# Agent Collaboration Protocol

> Purpose: keep architecture control stable across IDE restarts, network drops,
> long sessions, and worker-agent context drift.
>
> Status source: this file is the collaboration contract. Task state still lives
> in `.auto_coding/tasks/TRACKER.md` or the yeah_code daemon when available.

## Roles

| Role | Responsibility | May Edit Code |
|---|---|---|
| User | Product / architecture owner; approves red-zone changes | Yes |
| Controller Agent | Architecture gate, task slicing, worker instruction, diff review, final report | Yes, only when explicitly implementing |
| Worker Agent | Bounded implementation worker for one assigned task | Yes, only within assigned ownership |

The worker is not an architecture owner. It must not broaden scope, invent new
contracts, or "make it work first" in core backend paths.

## Session Recovery

At the start of any resumed session, the controller must read:

1. project `CLAUDE.md`, if present
2. `.auto_coding/start_coding.md` section 9
3. `.auto_coding/requirements/_ARCH_INVARIANTS.md`, if present
4. `.auto_coding/requirements/_ROADMAP.md`, if present
5. `.auto_coding/AGENT_COLLABORATION.md`
6. `git status --short`

Then report:

- current branch / dirty state
- active task, if known
- blocked validation, if any
- next proposed action

## Delegation Rules

The controller may delegate implementation to a worker only after writing a
bounded execution brief with:

- task goal
- owned files or modules
- files / modules explicitly out of scope
- architecture red lines involved
- validation commands
- expected final report format

Worker tasks should normally stay within 5 files and 300 changed lines. If that
is not realistic, split the task before implementation.

## Worker Hard Boundaries

Workers must stop and report instead of acting when a task touches:

- cross-repo writes outside the assigned repository
- version constants or release changelogs
- dependency or toolchain changes
- `.proto` semantic changes
- generated code direct edits
- Redis namespace ownership changes
- new Redis key patterns not represented in the project key builder
- persistent identity semantics such as `conversation_id` vs `session_id`
- sub-agent or external-agent control flow direction
- tests changed only to hide an implementation failure

## Review Gate

Every worker result must be reviewed by the controller before the user treats it
as accepted.

Review result labels:

- `OK`: safe to proceed.
- `MUST FIX`: correctness, build, security, ownership, or contract issue.
- `RISK`: requires user architecture decision.
- `STOP`: worker crossed a hard boundary; pause implementation.

The controller reviews the actual working tree, not only the worker summary.

## Validation Policy

Use the target project's declared validation commands. If a required external
service is unavailable, report the exact command and failure, then run the
narrowest build or package test that still proves the changed code compiles.

Environment failures must be separated from code failures. A compile error is
never an environment failure.

## Handoff Format

Controller final reports should include:

- what changed or what was reviewed
- whether worker output is accepted
- validation result
- remaining risks / next action

Worker final reports must include:

- files changed
- summary of behavior change
- validation commands and results
- known limitations
