# Contracts

## When to write one

A decision touches an interface when the chosen option adds or changes a public type, event, error category, field, endpoint, or message. Then:

1. Set `dec:touchesInterface true`. Otherwise set `false`. Required for decision number 3 and above.
2. Write one contract per affected layer (see Layer map). No Markdown contracts.
3. Set `dec:contract "docs/contracts/<name>-vN.<ext>"` for each file.
4. Set `dec:consumer` for each downstream layer or repo affected. Use the literal `none` if truly none.

## Which format

Rule: the boundary decides the format.

| Boundary | Format | File | Checked by |
|---|---|---|---|
| In-language API of a Python library | Type stub | `<name>-vN.pyi` | `mypy --strict` |
| In-language API of a TypeScript library | Declaration file | `<name>-vN.d.ts` | `tsc --strict` |
| Wire or process boundary: events, messages, WebSocket, queues | AsyncAPI 3.0 | `<name>-vN.asyncapi.yaml` | Spectral |
| Wire or process boundary: HTTP request/response, JSON data shapes, CLI JSON output | OpenAPI 3.1 | `<name>-vN.openapi.yaml` | Spectral |

- Use the language of the library. Do not force a library API into OpenAPI.
- OpenAPI/AsyncAPI only where data crosses a process or network boundary.
- OpenAPI for a data-only contract: `paths: {}` and `components.schemas`. Valid in 3.1.
- Do not model events as HTTP endpoints.
- A stub states signatures only: types, fields, `Protocol`s, `Literal`s. No logic, no implementation.
- Version suffix in the file name. A breaking change gets a new `vN` file. An additive change bumps `info.version` (or keeps the stub name) in the same file.
- Templates: `templates/contract.pyi`, `templates/contract.d.ts`, `templates/contract.openapi.yaml`, `templates/contract.asyncapi.yaml`.

## Layer map (end-to-end delivery)

A feature is not done until each layer that exposes it has a contract and a plan step. Verify each row by reading the repo. Do not trust this table.

| Layer | Repo (sibling dir `~/Documents/source/aigensa/<name>`) | Interface | Contract |
|---|---|---|---|
| SDK | harness-sdk | Python types, `HarnessResult`, error categories | `.pyi` stub |
| HTTP/WebSocket server | harness-http | WebSocket multi-turn protocol | AsyncAPI 3 (ws binding) |
| Scheduled CLI | harness-cli | CLI output, exit codes | OpenAPI 3.1 schemas |
| Orchestrator | factory (F07) | Maps SDK categories to `error_class` | consumer only |

For each affected layer, the plan lists: file to change, contract file, test.
If a layer needs no change, say why (cite a fact).

## Validation

`~/.claude/researcher/bin/validate-contracts.sh docs/contracts` checks every contract by its kind. Errors fail. Style warnings are off.

The hook runs it for you at stop. See `references/validation.md`.

Rules:
- Zero errors.
- Every `dec:contract` path exists. SHACL checks that.
- A contract states only what the decision fixes. Do not copy prose from the decision.
- A stub must stand alone: no imports from the project source. Re-declare the types it needs.
- No secrets, no real tokens, no private URLs in examples.
