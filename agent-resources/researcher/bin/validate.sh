#!/usr/bin/env bash
# Usage: validate.sh [decisions_dir=docs/decisions]
# Validates all *.ttl in the dir (not schema/) against <dir>/schema/decision.shapes.ttl.
# Exit 0 = conforms, 1 = violations, 2 = setup error. Needs uv.
set -euo pipefail
dir="${1:-docs/decisions}"
[ -f "$dir/schema/decision.ttl" ] && [ -f "$dir/schema/decision.shapes.ttl" ] || { echo "missing $dir/schema/*.ttl" >&2; exit 2; }
command -v uv >/dev/null || { echo "uv not installed" >&2; exit 2; }
exec uv run --no-project --quiet --with pyshacl --with rdflib python -I - "$dir" <<'PY'
import sys, glob, os
from rdflib import Graph, URIRef
from pyshacl import validate
d = sys.argv[1]
data = Graph()
files = sorted(f for f in glob.glob(os.path.join(d, "*.ttl")))
for f in files:
    data.parse(f, format="turtle")
shapes = Graph().parse(os.path.join(d, "schema", "decision.shapes.ttl"), format="turtle")
data.parse(os.path.join(d, "schema", "decision.ttl"), format="turtle")  # enum individuals + class types
conforms, _, text = validate(data, shacl_graph=shapes, inference="none", abort_on_first=False)
root = os.path.dirname(os.path.dirname(os.path.abspath(d)))
missing = [str(o) for o in data.objects(None, URIRef("urn:researcher:decision#contract")) if not os.path.isfile(os.path.join(root, str(o)))]
for m in missing: text += f"\nMessage: contract file not found: {m}"
conforms = conforms and not missing
print(f"files: {len(files)}  triples: {len(data)}")
print("CONFORMS" if conforms else text)
sys.exit(0 if conforms else 1)
PY
