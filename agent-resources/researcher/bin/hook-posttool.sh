#!/usr/bin/env bash
# PostToolUse hook (Write|Edit). After an edit to docs/decisions/*.ttl, runs `just decisions`.
# Fail: exit 2 (stderr goes to the model). Other paths or repos without the recipe: no-op.
set -uo pipefail
in="$(cat)"
f="$(jq -r '.tool_input.file_path // empty' <<<"$in")"
cwd="$(jq -r '.cwd // empty' <<<"$in")"
case "$f" in */docs/decisions/*.ttl) ;; *) exit 0 ;; esac
root="$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null || echo "${cwd:-.}")"
cd "$root" || exit 0
just --show decisions >/dev/null 2>&1 || exit 0
if ! v="$(just decisions 2>&1)"; then
  d="$(printf '%s\n' "$v" | grep -E 'Message|Focus Node|Result Path|missing|not found|error' | head -40)"
  printf 'just decisions FAILED after editing %s:\n%s\n' "$f" "${d:-$(printf '%s\n' "$v" | tail -15)}" >&2
  exit 2
fi
exit 0
