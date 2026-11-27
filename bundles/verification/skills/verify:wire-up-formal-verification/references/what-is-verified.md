# What each layer proves, and what it does not

Read this when reporting results to the user or when they ask "is this verified?". Each layer
answers a narrower question than the word "verified" suggests.

## Contents
1. SHACL  2. Probes  3. Z3  4. Alloy  5. TLA+  6. Lean  7. Model-vs-code gap

## 1. SHACL (structure)
- Proves: every record has the required fields and types, enum values are legal, ids are unique
  (story/seq pair, no padding), chosen option is a surviving option, weights sum to 1,
  confidence/reversibility rules hold, contract files named by `dec:contract` exist,
  Accepted decisions rest on confirmed facts.
- Does not prove: that any fact is true, that scores are sensible, that the chosen option wins,
  that prose matches the structured data. A well-formed lie passes.

## 2. Probes (facts vs code)
- Proves: a Fact's grep / hash / TOML-key check holds against the working tree now, and, when
  `dec:atCommit` is stamped, held at that commit. Drift (true then, false now) blocks until a newer
  Fact is linked with `dec:driftedTo`.
- Does not prove: the probe encodes the fact correctly (a loose regex passes), behaviour (grep
  is not semantics), or anything outside the probed file. Test probes run only with `--tests`;
  URL hash probes only with `--online`. Facts without probes are `UNVERIFIABLE` or
  `CONFIRMED-MANUAL` (a human said so).
- No git history: `atCommit` checks are skipped with a warning; probes run on the working tree.

## 3. Z3 (scoring logic)
- Proves, in exact rational arithmetic: weights are in [0,1] and sum to 1 (+-0.001); every
  surviving option has exactly one score per criterion, each in 0..5; the chosen option has the
  maximum weighted total (ties reported); the declared sensitivity (`Robust` / `Fragile`) matches a
  one-weight-at-a-time +-20% perturbation search, with a counterexample on mismatch.
- Does not prove: that the weights or 0..5 scores are right (garbage in, proof out), that
  criteria are complete, or that the options cover the design space. A joint +-20% flip can
  exist even when single-weight sensitivity is Robust; the report notes it but does not fail.

## 4. Alloy (relational / structural model)
- Proves: within the declared scope (e.g. 4 atoms per signature, 6 steps), no counterexample to
  the asserted properties exists. Good at invariants over states and relations (unique ids,
  open/closed lifecycle).
- Does not prove: anything beyond the scope (a bug needing 5 atoms is missed), anything about the
  code, or properties you did not assert. A `run` that finds an instance only shows the model is
  not vacuous.

## 5. TLA+ / TLC (concurrency and crash interleavings)
- Proves: for the finite constants in the `.cfg`, every reachable state satisfies the invariants
  and every behaviour satisfies the temporal properties under the stated fairness. Good at
  crash-between-steps and at-least-once delivery questions.
- Does not prove: unbounded cases (TLC is bounded model checking unless you write TLAPS
  proofs), liveness without the fairness assumptions you wrote, or that the code does what the
  spec's actions say.

## 6. Lean (machine-checked proofs)
- Proves: a theorem about a Lean function for ALL inputs (e.g. migrate is idempotent), with no
  bounds; the kernel checks it.
- Does not prove: that the Lean function is the code. Equivalence between the model and the
  production function is an unverified, manual claim unless the code is extracted or tested
  against the model.

## 7. Model-vs-code gap
Alloy, TLA+ and Lean verify a MODEL written by a person. Nothing links the model to the code
except review. Reduce the gap: keep names identical to the code, list which code path each model
action mirrors (header comment), add a conformance test that replays model traces or property
tests against the code, and re-review the model when the code changes. Report model results as
"the model satisfies X within bounds", never "the code satisfies X".
