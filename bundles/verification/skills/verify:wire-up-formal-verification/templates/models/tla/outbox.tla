------------------------------ MODULE outbox ------------------------------
\* Outbox starter. A writer saves a record, then registers it in a ledger; a crash may fall
\* between the two steps. A relay delivers saved records at least once; event ids are stable
\* (derived from the record, not from the delivery), so consumers can dedupe.
\* Run (needs Java + tla2tools.jar):
\*   cd models/tla && java -cp tla2tools.jar tlc2.TLC -config outbox.cfg outbox.tla
\* TLC explores every interleaving up to the bounds in outbox.cfg. It checks this MODEL, not your code.
EXTENDS Naturals, FiniteSets

CONSTANTS Records, MaxDeliveries      \* e.g. Records = {r1, r2}

VARIABLES saved, ledger, delivered, crashed
\* saved: records persisted; ledger: records registered for delivery;
\* delivered: [record -> count of deliveries]; crashed: writer is down

vars == <<saved, ledger, delivered, crashed>>
EventId(r) == r                       \* stable: same record => same event id on every redelivery

Init == /\ saved = {} /\ ledger = {} /\ crashed = FALSE
        /\ delivered = [r \in Records |-> 0]

Save(r)     == /\ ~crashed /\ r \notin saved
               /\ saved' = saved \cup {r}
               /\ UNCHANGED <<ledger, delivered, crashed>>
Register(r) == /\ ~crashed /\ r \in saved /\ r \notin ledger
               /\ ledger' = ledger \cup {r}
               /\ UNCHANGED <<saved, delivered, crashed>>
Crash       == /\ ~crashed /\ crashed' = TRUE      \* may strike between Save and Register
               /\ UNCHANGED <<saved, ledger, delivered>>
Recover     == /\ crashed /\ crashed' = FALSE
               \* recovery re-registers anything saved but missing from the ledger
               /\ ledger' = ledger \cup saved
               /\ UNCHANGED <<saved, delivered>>
Deliver(r)  == /\ r \in ledger /\ delivered[r] < MaxDeliveries
               /\ delivered' = [delivered EXCEPT ![r] = @ + 1]
               /\ UNCHANGED <<saved, ledger, crashed>>

Next == \/ \E r \in Records : Save(r) \/ Register(r) \/ Deliver(r)
        \/ Crash \/ Recover

Spec == Init /\ [][Next]_vars /\ WF_vars(Recover)
        /\ \A r \in Records : WF_vars(Register(r)) /\ WF_vars(Deliver(r))

\* Safety: nothing is delivered unless it was saved (no phantom events).
DeliveredWereSaved == \A r \in Records : delivered[r] > 0 => r \in saved
\* Liveness (at-least-once): every saved record is eventually delivered, even across a crash.
\* Fails if Recover is removed: that is the crash-between-save-and-register bug.
EventuallyDelivered == \A r \in Records : [](r \in saved => <>(delivered[r] >= 1))

TypeOK == /\ saved \subseteq Records /\ ledger \subseteq Records /\ crashed \in BOOLEAN
=============================================================================
