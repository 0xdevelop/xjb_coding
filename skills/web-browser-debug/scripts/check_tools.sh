#!/usr/bin/env bash
# Report which real-browser layer is available; never install, launch, or modify anything.
set -eu
printf 'platform: %s\n' "$(uname -s)"

if command -v ego-browser >/dev/null 2>&1; then
    printf 'ego-browser: %s\n' "$(command -v ego-browser)"
    if browser_version=$(ego-browser --version 2>&1); then
        printf '%s\n' "$browser_version"
        if browser_guide=$(ego-browser skill 2>&1); then
            case "$browser_guide" in
                *'[ego-browser:skill] end of guide'*)
                    printf 'layer: ego-browser\n'
                    printf 'Run ego-browser skill and read the complete guide before browser actions.\n'
                    printf 'CLI and guide checks do not prove browser connectivity or task capabilities.\n'
                    exit 0
                    ;;
                *) printf 'ego-browser skill: missing end-of-guide marker.\n' >&2 ;;
            esac
        else
            printf 'ego-browser skill failed; follow the official installation or upgrade guidance.\n' >&2
        fi
    else
        printf 'ego-browser --version failed.\n' >&2
    fi
else
    printf 'ego-browser: not on PATH.\n' >&2
fi

cat >&2 <<'HELP'
No ego-browser layer. Next: check the host tool list for a Playwright MCP (browser_navigate / browser_snapshot ...).
If that is missing too, stop and report the gap. Do not install, upgrade, or change the environment without authorization.
Read the current official ego-browser skill's references/install.md or https://lite.ego.app/ for the actual platform.
Read this Skill's references/ego-browser.md for discovery and upgrade rules.
HELP
exit 2
