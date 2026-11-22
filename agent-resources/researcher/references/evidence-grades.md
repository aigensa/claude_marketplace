# Evidence grades

| Grade | Meaning | Examples |
|---|---|---|
| A | Primary | Project code, config, measured data, official docs, license files, specs |
| B | Secondary | Reputable articles, third-party benchmarks, issue trackers |
| C | Inference or memory | Reasoning without a source |

## Rules

- Record for each fact: source (path or URL), date accessed, grade.
- A decision resting only on grade C = confidence LOW. Say so.
- Irreversible decision needs grade A support for each decisive fact.
- Licenses, versions, prices, limits change. Verify with a current source. Check the LICENSE file, not the blog post.
- Two sources conflict: prefer the higher grade. Record the conflict as a U-item if unresolved.
- Prefer primary sources over summaries.

## Probes

- A project fact graded A needs a probe. See `references/probes.md`.
- A probe proves the text or behaviour at a commit and now. It does not prove meaning.
- URL, issue, and chat facts are B or C and have no probe.
