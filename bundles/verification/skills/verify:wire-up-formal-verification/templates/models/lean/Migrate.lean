/-
  Migration idempotence starter (Lean 4, core only, no Mathlib).
  Run:  lean models/lean/Migrate.lean      (silence = every theorem checked; errors = failed proof)
  Models a PURE function `migrate` that upgrades a record to the latest schema version.
  Lemma: applying it twice equals applying it once, so re-running a migration is safe.
  This proves a property of the Lean model; mapping it to real code is a manual, reviewed step.
-/

structure Record where
  version : Nat
  payload : String
deriving DecidableEq

def latest : Nat := 3

/-- Upgrade one version step: v -> v+1 with a (placeholder) payload rewrite. -/
def step (r : Record) : Record :=
  { version := r.version + 1, payload := r.payload ++ "+" }

/-- Upgrade until `latest`; fuel makes termination obvious. Records at or above latest are untouched. -/
def migrateAux : Nat → Record → Record
  | 0, r => r
  | n + 1, r => if r.version < latest then migrateAux n (step r) else r

def migrate (r : Record) : Record := migrateAux latest r

/-- A record already at/after latest is a fixed point of migrateAux for any fuel. -/
theorem migrateAux_fixed (n : Nat) (r : Record) (h : latest ≤ r.version) :
    migrateAux n r = r := by
  cases n with
  | zero => rfl
  | succ n =>
    have : ¬ r.version < latest := Nat.not_lt.mpr h
    simp [migrateAux, this]

/-- Fuel `latest` is enough: the result is always at or above `latest`. -/
theorem migrateAux_reaches (n : Nat) (r : Record) (h : latest ≤ r.version + n) :
    latest ≤ (migrateAux n r).version := by
  induction n generalizing r with
  | zero => simpa [migrateAux] using h
  | succ n ih =>
    by_cases hlt : r.version < latest
    · simp only [migrateAux, hlt, if_true]
      apply ih
      simp [step]; omega
    · simp only [migrateAux, hlt, if_false]; omega

/-- Idempotence: migrating twice equals migrating once. -/
theorem migrate_idempotent (r : Record) : migrate (migrate r) = migrate r := by
  unfold migrate
  apply migrateAux_fixed
  apply migrateAux_reaches
  omega
