# Fact probes

A probe is a stored, deterministic check that a Fact is true. `bin/verify-facts.sh` runs them.

## When

- Every project Fact you grade A needs at least one probe (SHACL enforces it for decision number 5 and above).
- Facts from issues, chats, or the web stay grade B or C. No probe. They show as UNVERIFIABLE.
- Write the probe while you gather evidence. Use the narrowest check that still proves the fact.

## Kinds

| Kind | Fields | Passes when |
|---|---|---|
| `dec:GrepProbe` | `probeTarget` (repo-relative path), `probePattern` (Python regex, multiline), `probeExpect` (`dec:Present` or `dec:Absent`), optional `probeMinCount` | the pattern is found (Present, at least minCount, default 1) or not found (Absent) |
| `dec:HashProbe` | `probeTarget` (path, or https URL with `--online`), `probeSha256` | the content hash is unchanged |
| `dec:KeyProbe` | `probeTarget` (TOML file), `probeKeyPath` (dotted, `project.requires-python`), `probeExpected` (string) | the key has that value |
| `dec:TestProbe` | `probeTestId` (pytest node id) | the test passes. Runs only with `--tests` |

Rules:
- Match content, never line numbers. Lines move.
- Targets are repo-relative. No absolute path. No `..`.
- Escape regex characters. In Turtle strings write `\\(` for a literal bracket.
- A loose pattern can pass while the fact is wrong. Anchor on a distinctive token (a function name, a string literal).
- One Fact may have several probes. All must pass.

## Result per Fact

Each probe runs now (working tree) and at `dec:atCommit` (`git show <sha>:<path>`).

| At commit | Now | Result | Blocks the stop |
|---|---|---|---|
| pass | pass | HOLDS | no |
| pass | fail | DRIFT | yes, unless acknowledged |
| fail | any | WRONG | yes |
| cannot run | | ERROR | yes |
| no probe | | UNVERIFIABLE | no |

- `dec:atCommit` is stamped for you. At stop the hook runs `verify-facts.sh --stamp`. For each Fact without `atCommit` whose probes pass at `HEAD`, it writes `dec:atCommit` into the file. Do not write `atCommit` yourself.
- A new Fact whose probe fails at `HEAD` is WRONG. Fix the fact or the probe.

## DRIFT

Code changed after the fact was true. Do not edit the old Fact. Do not retire it if an Accepted decision uses it.
1. Add a newer Fact that records the current state, with its own probe.
2. On the old Fact set `dec:driftedTo d:<new fact>`. This is an acknowledged drift. It no longer blocks.
3. If the new Fact also drifts, the acknowledgement is void.

## Manual run

`~/.claude/researcher/bin/verify-facts.sh docs/decisions [--stamp] [--tests] [--online]`

## Confirmation

A Fact is confirmed when one of these holds:
- `dec:atCommit` is set. A probe passed. The Stop hook stamped it. This is confirmation on first evidence.
- `dec:confirmedBy` (`dec:Human` or `dec:SecondSource`), `dec:confirmedOn` and `dec:confirmedNote` are set. Use this for facts with no probe (issue bodies, URLs, untracked files).

Rules:
- `dec:SecondSource` means an independent check, such as a tool run or a second document. Say exactly what you ran in `dec:confirmedNote`.
- `dec:Human` means a person checked it. Never claim `dec:Human` yourself. Ask the caller.
- An `Accepted` decision may rest only on confirmed decisive facts (SHACL enforces it). A `Proposed` decision may use unconfirmed ones.
- Confirmation is a record of one check at one time. It does not stop later drift. A probe still reruns every time.
- `verify-facts.sh` shows `CONFIRMED-MANUAL` for these facts. It does not recheck them.
