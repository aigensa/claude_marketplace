---
name: "verify:wire-up-formal-verification"
description: Scaffold and validate a decision-record verification toolchain in a repo - SHACL-checked Turtle decision records (docs/decisions), git-aware fact probes, Z3 checks on weighted scoring, plus optional Alloy / TLA+ / Lean starter models. Use whenever the user says "wire up formal verification", "set up decision records with SHACL", "add Z3 scoring checks", "scaffold Alloy/TLA+ model", "add fact probes", "validate decisions in CI", "just decisions", or wants decision logs that are machine-checked rather than free-form ADR markdown, even if they name only one layer (SHACL, Z3, Alloy, TLA+, Lean).
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  # Bash justified: runs git probes, just/uv/pytest validation, and optional model tools (java, lean) in the target repo; no narrower tool can execute them.
  - Bash
  - AskUserQuestion
---

# verify:wire-up-formal-verification

Source snapshot: templates copied from the `chore/decisions-z3` branch, commit
`c810c9b955d73fc61a665dc5ebfbdea9462f03ce` of the aigensa factory repo (the only place that name appears).
The sample ids are generic (`D1-1`, story 1 seq 1).

## Purpose
Install, in a target repo, a toolchain that machine-checks decision records and optionally scaffolds
formal models:
1. SHACL: structure of `docs/decisions/*.ttl` plus existence of referenced contract files.
2. Probes: each Fact's grep/hash/TOML check against code, pinned to a git commit, with drift detection.
3. Z3: weights, scores, chosen-option-wins and declared Robust/Fragile sensitivity.
4. Optional models: Alloy, TLA+, Lean starters, run separately via `just models`.
What each layer does and does not prove: `references/what-is-verified.md`. Read it before telling the
user anything is "verified"; the models check a model, not the code.

## Workflow
Work in the target repo. Templates live in this skill's `templates/` directory, next to this SKILL.md
(call its absolute path `$T`; locate it with Glob if unknown). Do not push or commit unless the user asks; leave changes in the working tree.

1. **Detect the repo.** Check: git repo and history (`git rev-parse HEAD`); task runner (`justfile`,
   `Makefile`, neither); Python tests dir and runner (pytest config); `uv` (`command -v uv`); existing
   `docs/decisions`, `scripts/`, `tests/fixtures/`. Branch off if on main (user rule: no direct work on main).
2. **Ask** (one batched question): which layers (SHACL+probes+Z3 default; models yes/no; which of
   Alloy/TLA+/Lean); story-id convention (default: `D<story>-<seq>`, story = issue number, e.g.
   `d412-03-*.ttl`; alternatives: legacy `dec:number`, or another tracker id as `dec:story`); whether to
   keep or delete the sample record. Skip questions the repo already answers.
3. **Copy templates** (never overwrite; see Exceptions for merge):
   - `$T/schema/*.ttl` -> `docs/decisions/schema/`
   - `$T/sample/context.ttl`, `$T/sample/d1-01-sample.ttl` -> `docs/decisions/`
   - `$T/scripts/*` -> `scripts/` (keep `verify_facts.sh` executable)
   - `$T/models/` -> `models/` only if models were chosen.
4. **Wire the recipe.** Append `$T/justfile.snippet` `decisions` recipe to the justfile and add
   `decisions` to the `check` dependency list. Add the `models` recipe only if models were chosen, and
   never as a `check` dependency (needs Java/Lean, slow).
5. **Add tests and fixtures.** `$T/tests/test_verify_scoring.py` -> `tests/`; `$T/tests/fixtures/decisions/`
   -> `tests/fixtures/decisions/`. Fix `ROOT` in the test if the tests dir is not `<root>/tests`.
   Fixtures: `pass`, `story_seq` (valid); `wrong_winner`, `false_robust`, `false_fragile`, `bad_weights`
   (Z3 must fail them); duplicate story/seq and missing contract file are built in-test from the sample.
6. **Models (optional).** Models are generic starters (run lifecycle, outbox crash/at-least-once,
   migrate idempotence). Rename sigs/actions to the repo's domain, and add a header line mapping each
   model action to the code path it mirrors. State plainly that they prove nothing about the code yet.
7. **Run validation** (below). Fix template paths/names on failure; do not weaken checks to get green.
8. **Report** to the user: files added, recipes changed, each validation result, tools missing
   (`uv`, `z3` via `--with z3-solver`, `java`, Alloy/TLC jars, `lean`), and unresolved items
   (sample record to replace, model-to-code mapping, story-id convention).

## Validation
Run all; report each result verbatim-short.
1. `just decisions` exits 0 on the sample. Expect `CONFORMS`, `SUMMARY ...HOLDS=1`, `failures=0`.
2. Negative cases fail with the expected message (the template tests assert these):
   wrong winner `not max`; false Robust `declared Robust, Z3 found Fragile`; false Fragile
   `declared Fragile, Z3 found Robust`; bad weights `sum`; duplicate pair `share the same (dec:story, dec:seq)`;
   missing contract `contract file not found`. Run them via pytest, or by hand with
   `uv run --with z3-solver --with rdflib python -I scripts/verify_scoring.py tests/fixtures/decisions/<case>`.
3. Template tests pass: `.venv/bin/python -m pytest tests/test_verify_scoring.py` (or the repo's runner).
   They need `uv` and network access to fetch pyshacl/z3-solver on first run.
4. The repo's own suite still passes and `git diff --check` is clean.
5. If models were chosen and tools exist: Alloy (`java -jar alloy.jar exec -f ...`), TLC, `lean` per the
   header comment of each file. Tools missing: report "not run", never install them unasked. The model
   starters were not executed when this skill was authored; treat a syntax error as a template bug to fix.

## Exceptions
- **No justfile:** use the Makefile (`decisions:` target with the same three commands, add to `check`)
  or `scripts/decisions.sh` running them, and tell the user which CI step must call it.
- **No `uv`:** `pip install pyshacl rdflib z3-solver` into the repo venv and run
  `python -I scripts/<x>.py docs/decisions`. `verify_facts.sh` hard-requires `uv` (Python >= 3.11 for
  `tomllib`); with only pip, run its embedded Python by hand or stop and tell the user.
- **Existing `docs/decisions`:** merge, never overwrite. Skip files that exist and diff them instead;
  for an existing schema, show the diff and ask. Keep existing records untouched; `context.ttl` gets
  new items appended, not replaced. Existing records using other id schemes (`dec:number`) remain valid.
  Delete the sample only with user consent, and only after one real record validates.
- **No git history / not a repo:** `verify_facts.sh` prints a `WARN`, skips `dec:atCommit` checks and
  `--stamp`, and checks probes against the working tree. Say so in the report.
- **decisions dir not `docs/decisions`:** scripts derive the repo root as two levels above the dir;
  keep the `<root>/docs/decisions` layout.
- **Shape strictness:** the shapes require probes on Grade A facts, `touchesInterface` on every
  story/seq decision, and a status-quo option. Do not loosen shapes to fit existing records without asking.
