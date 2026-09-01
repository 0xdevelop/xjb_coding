# Neutral Plugin And Private MCP Design

## Goal

Make `yeah_coding` and `yeah_code` work as independent, host-neutral projects that are better together:

- `yeah_coding` is the workflow/plugin front end for Claude Code, Codex, Cursor, Trae, Windsurf, and other AI coding hosts.
- `yeah_code` is a standalone user-owned workflow backend. It can be used by `yeah_coding`, or directly by any MCP client that speaks Streamable HTTP.

## Product Boundary

`yeah_coding` must not imply Claude Code or Codex is the primary host. Host-specific docs only explain installation and configuration. Runtime semantics stay the same everywhere:

1. Skills mode is the default and fallback.
2. MCP mode is used only when the user has configured and connected `yeah_code`.
3. If MCP tools are unavailable, work continues in local skills/markdown fallback mode.

`yeah_code` must be described in the reverse direction: it is not just a backend for `yeah_coding`. It is a general MCP Streamable HTTP daemon for workflow state, task locking, approval, requirements, sessions, and dashboard control. Used together with `yeah_coding`, the experience is stronger because the skill prompts know how to use its tools.

## Privacy And Data Ownership

The projects do not add telemetry. `yeah_code` does not call an LLM provider, upload source code, or forward prompts. Data stays in the user's deployed daemon and SQLite database unless the user explicitly exposes that daemon to their own network, team, or enterprise environment.

The docs must state this explicitly:

- User code, diffs, tasks, approvals, and requirements belong to the user.
- `yeah_code` can be deployed locally, on a LAN, or privately in a company environment.
- Cloud or team deployments should use reverse proxy TLS and Bearer tokens.

## Tenant Isolation

`yeah_code` should provide simple tenant isolation without becoming a complex identity system.

Minimal implementation:

- Workflow tables store `tenant_id`.
- MCP tools accept optional `tenant_id`.
- MCP HTTP requests can set `X-Yeah-Tenant-ID`; the server injects it into tool arguments when missing.
- Empty tenant defaults to `default`, preserving local single-user behavior.
- List/next/drift/pending queries are scoped to the selected tenant.

This is isolation, not full enterprise auth. Operators can combine it with separate daemon instances, separate databases, reverse proxy routes, or Bearer tokens.

## Codex Plugin Shape

Codex plugin metadata must follow the current Codex plugin manifest shape:

- Keep `.codex-plugin/plugin.json`.
- Keep `skills: "./skills/"`.
- Do not declare `mcpServers` unless a real `.mcp.json` is present.
- Keep repo marketplace entries under `.agents/plugins/marketplace.json` with `policy.installation`, `policy.authentication`, and `category`.

This makes Codex behavior match Claude Code behavior: install the plugin for skills; configure MCP separately when desired.

## Validation

Before handoff:

- Validate Codex plugin manifest with the local validator or equivalent schema check.
- Run `go test ./...` and `go build ./...` in `yeah_code`.
- Run a focused MCP tenant-scope test that proves tenant A cannot see tenant B tasks through `task.next`.
