#!/usr/bin/env bash
# SubagentStop hook for the researcher agent.
# Runs fact probes (+ --stamp), SHACL on docs/decisions, and the contract checks (Spectral, mypy, tsc) on docs/contracts.
# Fail: exit 2 (blocks stop, stderr goes to the agent). Second failure (stop_hook_active): allow stop, warn.
set -uo pipefail
in="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$in")"
active="$(jq -r '.stop_hook_active // false' <<<"$in")"
root="$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${cwd:-.}")"
cd "$root" || exit 0
ls docs/decisions/*.ttl >/dev/null 2>&1 || exit 0   # no decision log: nothing to check
H="$HOME/.claude/researcher/bin"
msg=""; fail=0
if ! fp="$("$H/verify-facts.sh" docs/decisions --stamp 2>&1)"; then fail=1; msg+=$'FACT PROBES FAILED (docs/decisions):\n'"$(printf '%s\n' "$fp" | grep -E $'^(WRONG|ERROR|DRIFT)\t|SUMMARY|rror' | head -40)"$'\nHow to fix: WRONG = correct the fact or its probe. ERROR = fix the probe target or pattern. DRIFT = add a newer Fact (with a probe) that records the current state, then set dec:driftedTo on the old Fact.\n'; fi
if ! v="$("$H/validate.sh" docs/decisions 2>&1)"; then fail=1; msg+=$'SHACL FAILED (docs/decisions):\n'"$(printf '%s\n' "$v" | grep -E 'Message|Focus Node|Result Path|missing|not found|error' | head -40)"$'\n'; fi
if ! c="$("$H/validate-contracts.sh" docs/contracts 2>&1)"; then fail=1; msg+=$'CONTRACT LINT FAILED (docs/contracts):\n'"$(printf '%s\n' "$c" | grep -E 'error|✖' | head -40)"$'\n'; fi
if [ "$fail" -eq 0 ]; then
  jq -nc '{systemMessage:"researcher: decision log SHACL-valid, contracts lint-clean"}'
  exit 0
fi
if [ "$active" = "true" ]; then
  jq -nc --arg m "researcher stopped with INVALID output after one repair attempt:
$msg" '{systemMessage:$m}'
  exit 0
fi
printf 'Fix these, then stop. Edit only files in docs/decisions/ and docs/contracts/.\n%s' "$msg" >&2
exit 2
