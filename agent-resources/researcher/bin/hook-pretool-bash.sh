#!/usr/bin/env bash
# PreToolUse hook (Bash) for the researcher agent. Allows only:
#   ~/.claude/researcher/bin/validate.sh [dir]   (also $HOME/... or bare validate.sh path forms)
# dir: plain relative/absolute path, no shell metacharacters. Everything else: exit 2 (blocked).
set -uo pipefail
cmd="$(jq -r '.tool_input.command // empty' <<<"$(cat)")"
bin="$HOME/.claude/researcher/bin/validate.sh"
re='^(~|\$HOME|'"$HOME"')/\.claude/researcher/bin/validate\.sh( [A-Za-z0-9_./-]+)?$'
if [[ "$cmd" =~ $re ]] && [[ "$cmd" != *..* ]]; then exit 0; fi
echo "Blocked: researcher may only run $bin [decisions_dir]. Got: $cmd" >&2
exit 2
