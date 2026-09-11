#!/usr/bin/env bash
# Report which real-browser layer is available; never install, launch, or modify anything.
set -eu
platform=$(uname -s)
ego_skill_dir="${EGO_SKILLS_DIR:-$HOME/.local/share/ego/ego-skills}"
claude_link="$HOME/.claude/skills/ego-browser"
layer=""

printf 'platform: %s\n' "$platform"

if [[ "$platform" == "Darwin" ]]; then
    if command -v ego-browser >/dev/null 2>&1; then
        printf 'ego-browser: %s\n' "$(command -v ego-browser)"
        if version_output=$(ego-browser --version 2>&1); then
            printf '%s\n' "$version_output" | sed 's/^/  /'
            layer="ego-browser"
        else
            printf 'ego-browser --version failed; the App may need onboarding or an upgrade.\n' >&2
        fi
    else
        printf 'ego-browser: not on PATH (expected ~/.local/bin/ego-browser after ego lite onboarding).\n' >&2
    fi
    if [[ -f "$ego_skill_dir/SKILL.md" ]]; then
        printf 'official skill: %s\n' "$ego_skill_dir"
        for f in references/api.md references/install.md references/clearing-state.md; do
            if [[ -f "$ego_skill_dir/$f" ]]; then printf '  %s\n' "$f"; else printf '  missing %s\n' "$f" >&2; fi
        done
    else
        printf 'official skill: missing %s/SKILL.md\n' "$ego_skill_dir" >&2
        layer=""
    fi
    if [[ -L "$claude_link" ]]; then
        printf 'claude link: %s -> %s\n' "$claude_link" "$(readlink "$claude_link")"
    elif [[ -d "$claude_link" ]]; then
        printf 'claude link: %s is a directory copy, not a link; it can drift from the official skill.\n' "$claude_link" >&2
    else
        printf 'claude link: absent (Claude Code loads the official skill through ~/.claude/skills/ego-browser).\n' >&2
    fi
else
    printf 'ego lite ships for macOS only; use the host Playwright MCP on this platform.\n' >&2
fi

if [[ -z "$layer" ]]; then
    cat >&2 <<'HELP'
No ego-browser layer. Next: check the host tool list for a Playwright MCP (browser_navigate / browser_snapshot ...).
If that is missing too, stop and report; install only with user approval:
  macOS: sh ~/.local/share/ego/ego-skills/scripts/install.sh  (or download from https://lite.ego.app/)
  then finish ego lite onboarding in the App so the ego-browser command is registered.
Read this Skill's references/ego-browser.md for host wiring and upgrade rules.
HELP
    exit 2
fi
printf 'layer: %s\n' "$layer"
printf 'This confirms the CLI and skill files exist; it does not prove the App is running or a task space can be created.\n'
