# Formal methods

## Step 7. Elimination (hard constraints)

- Test every option against every HARD constraint.
- Fail = eliminate. Record the minimal set of constraints that caused the failure. This is the "why".
- All options fail: report which constraint to relax. That is the result.
- One survivor: log it. Skip scoring.

## Step 8. Weighted scoring

- Criteria come from the context (goals, SOFT constraints). Not from taste.
- Weight each criterion. Justify each weight in one line. Weights sum to 1.
- Score 0-5 per criterion. Each score cites a fact ID (F-n).
- Total = sum(weight x score).
- Show the table in the decision file.

## Step 9. Pareto

- Needed when objectives conflict (cost vs risk vs time).
- Option X dominates Y if X is at least as good on every criterion and better on one.
- Pareto set = options no other option dominates.
- One option dominates all: say so. No trade-off.
- Else pick by the stated weights. List the trade-off.

## Step 10. Sensitivity

- Shift each weight by +20% and -20%. Renormalize. Recompute.
- Winner unchanged for all shifts: ROBUST.
- Winner changes: FRAGILE. Name the weight and the flip point.
- FRAGILE caps confidence at MEDIUM.

## Step 11. Minimality claim

Two meanings. Claim only what you checked.

- **Minimum**: no surviving option has a better total under the metric.
- **Irreducible**: no single element of the chosen change can be dropped and still meet the hard constraints.

Always state:
- model (which facts)
- option set (which options)
- metric (which weights)
- claim type (minimum or irreducible)

If the option set may be incomplete, write "minimum of the listed options".

## Explain why cheaper options fail

Name the smallest set of constraints that rules out each cheaper option (unsatisfiable core). Stakeholders accept this faster than scores.

## Optional solver

No shell access. For combinatorial problems (ordering, placement, many constraints):

- Write a runnable Z3 Optimize or MaxSAT script in the decision file as `dec:formalModel` (status `dec:Unverified`).
- Encode: each change as a Bool, hard constraints as `add`, cost as `minimize`.
- Mark the result UNVERIFIED until the caller runs it.
- Never claim solver proof you did not obtain.
- When the caller runs it: `unsat` on `cost < k` proves no cheaper plan exists within the model.
