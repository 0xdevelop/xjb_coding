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
- wire-contract semantic changes (`.proto`, API schema, event payloads)
- generated code direct edits
- storage namespace ownership changes (DB / cache key prefixes, topics, buckets)
- new storage key patterns not represented in the project's key builder
- semantics of long-lived identity fields (user / session / entity ID meaning)
- sub-agent or external-agent control flow direction
- tests changed only to hide an implementation failure

## Environment And Installation Stop Rules

Workers must stop and ask before:

- editing shell profiles or global config: `~/.zshrc`, `~/.bashrc`,
  `~/.profile`, `~/.gitconfig`, `~/.ssh/config`
- editing project env files: `.env*`, IDE launch configs, CI secrets/config
- setting persistent environment variables
- running package/system installers: `brew install`, `brew upgrade`, `apt`,
  `pip install`, `npm install`, `pnpm install`, `bun install`
- running dependency mutation commands: `go get`, `go mod tidy`, `cargo add`,
  lockfile rewrites
- downloading binaries or modifying `PATH`
- changing system services, launch agents, systemd units, login items

Allowed without approval:

- temporary env vars scoped to one displayed command
- running existing project scripts that do not mutate dependencies or global
  config
- reading config files

## Review Gate

Every worker result must be reviewed by the controller before the user treats it
as accepted.

Review runs against the four-layer gate model in `start_coding.md` §3
(L1 engineering / L2 architecture / L3 business / L4 project extension).
An all-green toolchain run only satisfies L1 and never means "accepted".

Review result labels:

- `OK`: all applicable gate layers pass; safe to proceed.
- `MUST FIX`: L1/L2 failure — correctness, build, security, ownership, or contract issue.
- `RISK`: requires user architecture decision.
- `STOP`: worker crossed a hard boundary; pause implementation.

The controller reviews the actual working tree, not only the worker summary.
Negative claims in worker reports ("missing", "not migrated", "dead code")
must be re-verified against real files before being repeated to the user.

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
