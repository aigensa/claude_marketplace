#!/usr/bin/env bash
# Usage: validate-contracts.sh [contracts_dir=docs/contracts]
# Lints *.openapi.* and *.asyncapi.* with Spectral. Checks *.pyi with mypy --strict, *.d.ts with tsc --strict.
# Exit 0 = valid or none found, 1 = errors, 2 = setup error. Needs node (npx).
set -euo pipefail
[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
dir="${1:-docs/contracts}"
rules="$(cd "$(dirname "$0")/.." && pwd)/schema/.spectral.yaml"
[ -d "$dir" ] || { echo "NO CONTRACTS (no $dir)"; exit 0; }
api=(); pyi=(); dts=()
while IFS= read -r f; do api+=("$f"); done < <(find "$dir" -maxdepth 2 -type f \( -name '*.openapi.yaml' -o -name '*.openapi.yml' -o -name '*.openapi.json' -o -name '*.asyncapi.yaml' -o -name '*.asyncapi.yml' -o -name '*.asyncapi.json' \) | sort)
while IFS= read -r f; do pyi+=("$f"); done < <(find "$dir" -maxdepth 2 -type f -name '*.pyi' | sort)
while IFS= read -r f; do dts+=("$f"); done < <(find "$dir" -maxdepth 2 -type f -name '*.d.ts' | sort)
total=$(( ${#api[@]} + ${#pyi[@]} + ${#dts[@]} ))
[ "$total" -gt 0 ] || { echo "NO CONTRACTS in $dir"; exit 0; }
rc=0
if [ "${#api[@]}" -gt 0 ]; then
  command -v npx >/dev/null || { echo "npx not installed" >&2; exit 2; }
  npx --yes @stoplight/spectral-cli lint --ruleset "$rules" --fail-severity error "${api[@]}" || rc=1
fi
if [ "${#pyi[@]}" -gt 0 ]; then
  command -v uv >/dev/null || { echo "uv not installed" >&2; exit 2; }
  uv run --no-project --quiet --with mypy mypy --strict --no-incremental --cache-dir=/dev/null "${pyi[@]}" || rc=1
fi
if [ "${#dts[@]}" -gt 0 ]; then
  command -v npx >/dev/null || { echo "npx not installed" >&2; exit 2; }
  npx --yes -p typescript tsc --noEmit --strict --skipLibCheck false "${dts[@]}" || rc=1
fi
[ "$rc" -eq 0 ] && echo "CONTRACTS VALID ($total files)"
exit "$rc"
