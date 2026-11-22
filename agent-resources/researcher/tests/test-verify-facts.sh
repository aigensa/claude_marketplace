#!/usr/bin/env bash
# Self-test for verify-facts.sh. Builds a temp git repo. Usage: test-verify-facts.sh
set -euo pipefail
V="$(cd "$(dirname "$0")/.." && pwd)/bin/verify-facts.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T"; git init -q; git config user.email t@t; git config user.name t
mkdir -p docs/decisions src
printf 'def f():\n    return 1\n' > src/a.py
printf '[project]\nrequires-python = ">=3.11"\n' > pyproject.toml
git add -A; git commit -qm A; A=$(git rev-parse HEAD)
printf 'def g():\n    return 2\n' > src/a.py          # f() removed: drift for F-2
git add -A; git commit -qm B
SHA256=$(shasum -a 256 pyproject.toml | cut -d' ' -f1)
cat > docs/decisions/context.ttl <<TTL
@prefix dec: <urn:researcher:decision#> .
@prefix d: <urn:decisions:> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
d:F-1 a dec:Fact ; dec:atCommit "$A" ; dec:probe d:P-1 .
d:P-1 a dec:Probe ; dec:probeKind dec:GrepProbe ; dec:probeTarget "pyproject.toml" ; dec:probePattern "requires-python" ; dec:probeExpect dec:Present .
d:F-2 a dec:Fact ; dec:atCommit "$A" ; dec:probe d:P-2 .
d:P-2 a dec:Probe ; dec:probeKind dec:GrepProbe ; dec:probeTarget "src/a.py" ; dec:probePattern "def f\\\\(" ; dec:probeExpect dec:Present .
d:F-3 a dec:Fact ; dec:atCommit "$A" ; dec:probe d:P-3 .
d:P-3 a dec:Probe ; dec:probeKind dec:GrepProbe ; dec:probeTarget "src/a.py" ; dec:probePattern "never_existed" ; dec:probeExpect dec:Present .
d:F-4 a dec:Fact ; dec:atCommit "$A" ; dec:probe d:P-4 .
d:P-4 a dec:Probe ; dec:probeKind dec:GrepProbe ; dec:probeTarget "nope.py" ; dec:probePattern "x" ; dec:probeExpect dec:Present .
d:F-5 a dec:Fact ; dec:atCommit "$A" ; dec:driftedTo d:F-6 ; dec:probe d:P-2 .
d:F-6 a dec:Fact ; dec:probe d:P-6 .
d:P-6 a dec:Probe ; dec:probeKind dec:GrepProbe ; dec:probeTarget "src/a.py" ; dec:probePattern "def g\\\\(" ; dec:probeExpect dec:Present .
d:F-7 a dec:Fact ; dec:atCommit "$A" ; dec:probe d:P-7 .
d:P-7 a dec:Probe ; dec:probeKind dec:KeyProbe ; dec:probeTarget "pyproject.toml" ; dec:probeKeyPath "project.requires-python" ; dec:probeExpected ">=3.11" .
d:F-8 a dec:Fact .
d:F-9 a dec:Fact ; dec:probe d:P-6 .
d:F-10 a dec:Fact ; dec:atCommit "$A" ; dec:probe d:P-10 .
d:P-10 a dec:Probe ; dec:probeKind dec:HashProbe ; dec:probeTarget "pyproject.toml" ; dec:probeSha256 "$SHA256" .
d:F-12 a dec:Fact ; dec:confirmedBy dec:SecondSource ; dec:confirmedOn "2026-11-22"^^xsd:date ; dec:confirmedNote "n" .
d:F-11 a dec:Fact ; dec:itemStatus dec:Retired ; dec:probe d:P-3 .
TTL
fail=0
out="$("$V" docs/decisions || true)"; echo "$out"
chk() { echo "$out" | grep -qE "$1" && echo "ok   $2" || { echo "FAIL $2"; fail=1; }; }
chk $'^DRIFT\tF-2\t'          "F-2 DRIFT"
chk $'^WRONG\tF-3\t'          "F-3 WRONG (never true)"
chk $'^ERROR\tF-4\t'          "F-4 ERROR (missing file)"
chk $'^DRIFT-ACK\tF-5\t'      "F-5 DRIFT-ACK via driftedTo"
chk $'^UNVERIFIABLE\tF-8\t'   "F-8 UNVERIFIABLE (no probe)"
chk $'^CONFIRMED-MANUAL\tF-12\t' "F-12 CONFIRMED-MANUAL"
echo "$out" | grep -qE $'\tF-1\t|\tF-7\t|\tF-10\t|\tF-11\t' && { echo "FAIL F-1/F-7/F-10/F-11 should be HOLDS or retired (silent)"; fail=1; } || echo "ok   F-1 F-7 F-10 HOLDS, F-11 retired skipped"
chk "SUMMARY WRONG=1 ERROR=1 DRIFT=1 DRIFT-ACK=1 UNVERIFIABLE=1 CONFIRMED-MANUAL=1 HOLDS=5" "summary counts"
rc=0; "$V" docs/decisions >/dev/null || rc=$?; [ "$rc" -eq 1 ] && echo "ok   exit 1 on failures" || { echo "FAIL exit code $rc"; fail=1; }
# stamp: F-9 has no atCommit and its probe passes at HEAD
HEAD_SHA=$(git rev-parse HEAD)
"$V" docs/decisions --stamp >/dev/null || true
grep -q "d:F-9 a dec:Fact ; dec:atCommit \"$HEAD_SHA\"" docs/decisions/context.ttl && echo "ok   --stamp wrote atCommit for F-9" || { echo "FAIL stamp"; fail=1; }
exit $fail
