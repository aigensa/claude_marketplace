-- Run lifecycle starter (Alloy 6). Models: runs that are opened and closed, with unique attempt ids.
-- Run:  java -jar alloy.jar exec -f models/alloy/run_lifecycle.als      (Alloy 6 CLI; or open in the Alloy Analyzer)
-- `check` commands report a counterexample or "no counterexample found" within the scope.
-- This checks the MODEL, not your code. Keep names aligned with the code so a reviewer can map them.

sig Attempt {}                                 -- attempt id; one signature atom per distinct id

abstract sig State {}
one sig Open, Closed extends State {}

sig Run {
  var state: one State,                        -- mutable field: changes over time (Alloy 6)
  var attempts: set Attempt                    -- attempts recorded so far
}

fact init { all r: Run | r.state = Open and no r.attempts }

-- Transitions
pred addAttempt[r: Run, a: Attempt] {
  r.state = Open
  a not in Run.attempts                        -- id uniqueness enforced ACROSS runs
  attempts' = attempts + r -> a
  state' = state
}
pred close[r: Run] {
  r.state = Open
  state' = state ++ r -> Closed
  attempts' = attempts
}
pred stutter { state' = state and attempts' = attempts }

fact trans { always ((some r: Run, a: Attempt | addAttempt[r, a]) or (some r: Run | close[r]) or stutter) }

-- Properties
assert closedStaysClosed { always (all r: Run | r.state = Closed implies always r.state = Closed) }
assert attemptIdsUnique  { always (all disj r1, r2: Run | no (r1.attempts & r2.attempts)) }
assert noAttemptAfterClose { always (all r: Run | r.state = Closed implies r.attempts' = r.attempts) }

check closedStaysClosed    for 4 but 1..6 steps
check attemptIdsUnique     for 4 but 1..6 steps
check noAttemptAfterClose  for 4 but 1..6 steps

-- Sanity: the model is not vacuous (a closed run with attempts is reachable).
run reachClosedWithAttempt { eventually (some r: Run | r.state = Closed and some r.attempts) } for 3 but 1..6 steps
