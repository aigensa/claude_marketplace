"""Validate docs/decisions/*.ttl against docs/decisions/schema/decision.shapes.ttl.

Usage: uv run --with pyshacl --with rdflib python -I scripts/validate_decisions.py [dir]
Exit 0 = conforms, 1 = violations, 2 = setup error.
"""

import glob
import os
import sys

from pyshacl import validate
from rdflib import Graph, URIRef

CONTRACT = URIRef("urn:researcher:decision#contract")


def main(d: str) -> int:
    ontology = os.path.join(d, "schema", "decision.ttl")
    shapes_path = os.path.join(d, "schema", "decision.shapes.ttl")
    if not (os.path.isfile(ontology) and os.path.isfile(shapes_path)):
        print(f"missing {d}/schema/*.ttl", file=sys.stderr)
        return 2
    data = Graph()
    files = sorted(glob.glob(os.path.join(d, "*.ttl")))
    for f in files:
        data.parse(f, format="turtle")
    shapes = Graph().parse(shapes_path, format="turtle")
    data.parse(ontology, format="turtle")  # enum individuals + class types
    conforms, _, text = validate(data, shacl_graph=shapes, inference="none")
    root = os.path.dirname(os.path.dirname(os.path.abspath(d)))
    for o in data.objects(None, CONTRACT):
        if not os.path.isfile(os.path.join(root, str(o))):
            conforms = False
            text += f"\nMessage: contract file not found: {o}"
    print(f"files: {len(files)}  triples: {len(data)}")
    print("CONFORMS" if conforms else text)
    return 0 if conforms else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/decisions"))
