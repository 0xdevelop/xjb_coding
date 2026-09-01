# Neutral Plugin And Private MCP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `yeah_coding` host-neutral and make `yeah_code` a standalone private MCP backend with simple tenant isolation.

**Architecture:** `yeah_coding` remains a skills-first plugin for every host and treats MCP as an optional enhancement. `yeah_code` remains an independent MCP Streamable HTTP daemon and adds tenant scope to workflow data without introducing heavy authentication.

**Tech Stack:** Markdown docs, Codex plugin manifest JSON, Go, SQLite, MCP Streamable HTTP.

---

### Task 1: Document The Accepted Boundary

**Files:**
- Create: `docs/superpowers/specs/2026-05-29-neutral-plugin-and-private-mcp-design.md`
- Create: `docs/superpowers/plans/2026-05-29-neutral-plugin-and-private-mcp.md`

- [x] **Step 1: Write the design**

Capture the independent-but-better-together relationship and the no-telemetry/private-deployment rule.

- [x] **Step 2: Write this implementation plan**

Use exact paths and validation commands.

### Task 2: Add Tenant Scope Tests In `yeah_code`

**Files:**
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/task/task_test.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/api/api_mcp/api_mcp_test.go`

- [ ] **Step 1: Add a failing task tenant test**

Add `TestNextAvailableScopesByTenant` that creates tasks in `tenant-a` and `tenant-b`, locks/completes tenant A work, and verifies tenant A never receives tenant B work.

- [ ] **Step 2: Add a failing MCP header injection test**

Add `TestTenantHeaderInjectedIntoToolArguments` that posts a `task.add` MCP call with `X-Yeah-Tenant-ID: tenant-a` and verifies the created task is stored with `tenant-a`.

- [ ] **Step 3: Run focused tests and confirm failure**

Run:

```bash
go test ./task ./api/api_mcp
```

Expected before implementation: tests fail because tasks do not have `tenant_id` yet.

### Task 3: Implement Tenant Scope In `yeah_code`

**Files:**
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/models/models.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/db/db.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/task/task.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/requirement/requirement.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/approval/approval.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/api/api_mcp/api_mcp.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/api/api_config/api_config.go`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/config/config.go`

- [ ] **Step 1: Add `tenant_id` columns and indexes**

Add tenant columns to workflow tables and idempotent migrations.

- [ ] **Step 2: Thread tenant filters through domain packages**

Add tenant fields to options and filters. Preserve existing wrappers with `default`.

- [ ] **Step 3: Thread tenant through MCP tools**

Add optional `tenant_id` to schemas and inject `X-Yeah-Tenant-ID` into tool arguments.

- [ ] **Step 4: Run focused tests and confirm green**

Run:

```bash
go test ./task ./api/api_mcp ./requirement ./approval
```

### Task 4: Update User-Facing Docs And Skills

**Files:**
- Modify: `README.md`
- Modify: `plugins/yeah-coding/skills/yeah-coding/SKILL.md`
- Modify: `plugins/yeah-coding/skills/yeah-coding-codex/SKILL.md`
- Modify: `/Users/wmyeah/workSpace/projects/github.com/0xYeah/yeah_code/README.md`

- [ ] **Step 1: Update `yeah_coding` docs**

Make Claude Code and Codex peer hosts. State skills are default/fallback and MCP is optional enhancement.

- [ ] **Step 2: Update `yeah_code` docs**

Describe direct MCP usage, private deployment, data ownership, and tenant scope.

- [ ] **Step 3: Update skill prompts**

Keep runtime behavior host-neutral and explicitly avoid telemetry or automatic external service use.

### Task 5: Validate

**Files:**
- Read/check: `plugins/yeah-coding/.codex-plugin/plugin.json`
- Read/check: `.agents/plugins/marketplace.json`

- [ ] **Step 1: Validate Codex plugin manifest**

Run:

```bash
python3 /Users/wmyeah/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/yeah-coding
```

If the local validator lacks Python dependencies, use a JSON/schema-equivalent fallback and report the dependency failure separately.

- [ ] **Step 2: Validate Go backend**

Run:

```bash
go test ./...
go build ./...
```

- [ ] **Step 3: Inspect diffs**

Run:

```bash
git diff --check
git status --short
```
