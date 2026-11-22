#!/usr/bin/env bash
# Usage: index.sh [decisions_dir=docs/decisions] [query.rq]
# Prints the decision index (or any SPARQL query result) as TSV. Needs uv.
set -euo pipefail
dir="${1:-docs/decisions}"; q="${2:-$(dirname "$0")/../queries/index.rq}"
exec uv run --no-project --quiet --with rdflib python -I - "$dir" "$q" <<'PY'
import sys, glob, os
from rdflib import Graph
g = Graph()
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.ttl"))): g.parse(f, format="turtle")
g.parse(os.path.join(sys.argv[1], "schema", "decision.ttl"), format="turtle")
res = g.query(open(sys.argv[2]).read())
print("\t".join(str(v) for v in res.vars))
for row in res: print("\t".join("" if c is None else str(c).replace("urn:researcher:decision#","dec:") for c in row))
PY
