# Validation

Two layers. A Stop hook runs the machine layer. You run the judgment layer.

## Layer 1. Machine (automatic, at stop)

`bin/hook-stop.sh` runs when you try to finish:

0. Fact probes (`bin/verify-facts.sh --stamp`): WRONG, ERROR, or unacknowledged DRIFT blocks the stop. See `references/probes.md`.
1. SHACL on `docs/decisions/*.ttl` (`bin/validate.sh`). Also checks each `dec:contract` file exists.
2. Contracts in `docs/contracts/` (`bin/validate-contracts.sh`): Spectral for OpenAPI/AsyncAPI, `mypy --strict` for `.pyi`, `tsc --strict` for `.d.ts`.

- Both pass: you stop. Report `VALIDATION: VALIDATED (hook)`.
- Either fails: the hook blocks the stop and lists the errors. Fix them. Edit only `docs/decisions/` and `docs/contracts/`. Finish again.
- The hook gives one repair attempt. If it still fails, it lets you stop and shows a warning. Report `VALIDATION: FAILED` and list the remaining errors under GAPS.
- No `docs/decisions/*.ttl` in the repo: the hook does nothing.

You have no shell. Read `references/decision-log.md` and `references/contracts.md` so your first draft passes.

## Layer 2. Judgment (no tool can check these)

- [ ] Decision question is one sentence.
- [ ] Options include status quo and one cheap hybrid if plausible.
- [ ] Every elimination reason names a real hard constraint, not a preference.
- [ ] Weights come from context, each with a reason.
- [ ] Sensitivity run. Fragility stated.
- [ ] Minimality claim says exactly what was checked.
- [ ] Confidence matches evidence grades.
- [ ] Unknowns listed.
- [ ] No contradiction with a prior accepted decision, or supersession recorded.
- [ ] Interface decisions: every affected layer has a contract or a cited reason it does not.
- [ ] Contract matches the decision. It states no more and no less.
- [ ] No file written outside `docs/decisions/` and `docs/contracts/`.

Fix each failure. If one stays, list it under GAPS.
