<!--
FIXTURE: grounding-docs-not-evidence
LENS: grounding (spec)
EXPECTED: BLOCKING
COVERS: §2's load-bearing premise is sourced to a CLAUDE.md sentence rather than to
  code, and §4 asserts a provider is reachable by injection when the module only
  lists it in `providers` (not `exports`) — a boot-time DI failure that build and
  unit tests both stay green through. Also: §3 claims "no helper exists" from a
  single grep.
EXPECTED REPORT (substring match):
  not evidence
  exported
  two
MUST NOT REPORT: whether the design is good (that is `design`), or unstated
  failure paths (that is `absence`).
ASSUMES: a repo where a module system distinguishes provided from exported, and
  where CLAUDE.md exists. The lens must attempt to verify against code and report
  UNVERIFIABLE for anything it cannot reach — not accept the prose.
-->

---
title: rules service reuse
created: 2026-07-29
---

# Rule evaluation in the reporting path

## 1. Goal

Let the reporting API evaluate calculation rules when rendering a period summary.

## 2. Existing behavior

`reporting/CLAUDE.md` states that the reporting API already accepts the embed
access token as a JWT fallback on every guarded route, so no auth work is needed
here. That is the premise this design rests on.

## 3. Helper

There is no existing string-to-decimal coercion helper — `grep -rn "toDecimal"`
returns nothing — so this design adds `toDecimal()` in
`libs/shared/rules/src/lib/to-decimal.ts`.

## 4. Wiring

`ReportingService` constructor-injects `RulesRepository` from `RulesModule`.
`RulesModule` already declares `RulesRepository` in its `providers`, so the
injection resolves.

## 5. Layer map

| Layer | Location |
|---|---|
| Service | `apps/api/src/reporting/reporting.service.ts` |
| Repository | `apps/api/src/rules/rules.repository.ts` |

## 6. Acceptance criteria

- A period summary includes an `evaluated` field per rule.
- `nx build api` is green.
