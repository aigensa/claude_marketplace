# Decision log (Turtle + SHACL)

The log is RDF. No Markdown. Shapes validate it.

## Location

`docs/decisions/` in the project root.

| Path | Content |
|---|---|
| `NNNN-slug.ttl` | One decision. Template: `templates/decision.ttl`. |
| `context.ttl` | Facts, constraints, assumptions, unknowns, glossary, open questions. Template: `templates/context.ttl`. |
| `schema/decision.ttl` | Ontology. Copy of `~/.claude/researcher/schema/decision.ttl`. |
| `schema/decision.shapes.ttl` | SHACL shapes. Copy of `~/.claude/researcher/schema/decision.shapes.ttl`. |

## Setup (first decision in a project)

1. If `docs/decisions/schema/` is missing, Read both schema files from `~/.claude/researcher/schema/`. Write them to `docs/decisions/schema/`.
2. If it exists, compare `owl:versionInfo` in both `decision.ttl` files. The home copy is newer: overwrite the project copy.
3. Read the Turtle files in `docs/decisions/` to find the next number and the next free F-/C-/A-/U- IDs.

## IRIs

- Prefix `d:` = `<urn:decisions:>`. Prefix `dec:` = `<urn:researcher:decision#>`.
- Decision `d:D0007`. Its nodes `d:D0007-O1` (option), `-K1` (criterion), `-S21` (score option 2 criterion 1), `-M`, `-R1`, `-Q1`.
- Context items `d:F-12`, `d:C-3`, `d:A-7`, `d:U-4`. Global and stable. Never reuse an ID.

## Rules

- Every grade A project fact has a `dec:probe` (see `references/probes.md`). Do not write `dec:atCommit`: the Stop hook stamps it.
- Typed nodes only. No prose sections. Free text goes in `dec:text`, `dec:summary`, `dec:note`, `dec:eliminationReason`. Keep each to one or two sentences.
- Reference context items by IRI. Do not copy their text into the decision file.
- Put each new fact, constraint, assumption, unknown in `context.ttl`. Set `dec:originDecision`.
- List every context item the decision relies on in `dec:uses`. List the evidence it rests on in `dec:decisiveFact`.
- Never edit the body of an Accepted decision. To change it: write a new decision with `dec:supersedes`. In the old file set `dec:status dec:Superseded` and `dec:supersededBy`. Those two edits are the only allowed edits.
- Retire context items with `dec:itemStatus dec:Retired`, `dec:retiredOn`, `dec:retiredReason`. Never delete.
- A Proposed or Accepted decision must not use a Retired item.
- Date every entry with the date from the environment.
- Read a file before you edit it. Write only inside `docs/decisions/` and `docs/contracts/`. Never commit, stage, or push.
- No git repo or no write access: return the Turtle in the reply.

## Index

No index file. Derive it: `~/.claude/researcher/bin/index.sh docs/decisions` (SPARQL, TSV). Query: `queries/index.rq`.

## Validation

Automatic. A Stop hook runs `bin/verify-facts.sh --stamp` (fact probes), `bin/validate.sh` (SHACL) and `bin/validate-contracts.sh` when the researcher finishes. See `references/validation.md`.

Manual: `~/.claude/researcher/bin/validate.sh docs/decisions` → `CONFORMS` or a violation list. Needs `uv`.

The shapes enforce: Accepted decisions rest on confirmed decisive facts, option count, status-quo option, chosen option present and not eliminated, elimination only by HARD constraints, weights sum to 1, scores 0-5 with fact evidence, grade rules for confidence, sensitivity rule for HIGH, supersession links, retired-item use, unique numbers, `dec:touchesInterface` (required from decision 3), contract path pattern and existence, `dec:consumer` for interface decisions.
