#!/usr/bin/env bash
# Inspect official external tools; never install or launch a server.
set -eu
missing=0
cli=${COMFY_BIN:-comfy}
if command -v "$cli" >/dev/null 2>&1; then
    printf 'comfy-cli: %s\n' "$(command -v "$cli")"
    "$cli" --version || missing=1
else
    printf 'Missing comfy-cli (comfy / COMFY_BIN).\n' >&2
    missing=1
fi
if command -v comfy-mcp >/dev/null 2>&1; then
    printf 'comfy-mcp: %s\n' "$(command -v comfy-mcp)"
    comfy-mcp --version || missing=1
else
    printf 'Missing comfy-mcp on PATH. If the MCP host uses an absolute executable path, check that registration separately.\n' >&2
    missing=1
fi
if [[ "$missing" != 0 ]]; then
    cat >&2 <<'HELP'
Install the official tools only when authorized, in a separate Python 3.10+ environment:
  python -m pip install comfy-mcp 'comfy-cli>=1.14.0'
Reuse an existing ComfyUI workspace; do not run comfy install for it.
For isolated setup and MCP registration, read this Skill's references/local-api.md.
Official sources:
  https://github.com/Comfy-Org/comfy-mcp
  https://github.com/Comfy-Org/comfy-cli
HELP
    exit 2
fi
printf 'Executables found. This does not verify MCP registration, live ComfyUI or local-only execution.\n'
