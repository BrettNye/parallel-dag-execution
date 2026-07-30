<!--
FIXTURE: verifiability-regression-guard
LENS: verifiability (plan)
EXPECTED: DEFERRED (reporting it is correct; BLOCKING on it is the regression)
SHAPE: plan only — no parent spec needed, the ACs are the subject. Ignore this block.
COVERS: the severity gate on a *correctly framed* weak assertion. `task-pin`'s AC is a
  grep for the absence of a string in a lockfile — a diff-property assertion that
  would pass if the grep pattern were wrong, the file moved, or the command errored.
  Naming that shape is right. But the task body states the condition ALREADY HOLDS and
  labels the check a regression guard rather than a gate, so nothing ships broken if
  the assertion is weak: it is guarding a state that is already true. DEFERRED.
  The lens should propose the positive-with-control form (grep returns exactly one
  line AND that line contains the wanted version) without blocking on it.
EXPECTED REPORT (substring match):
  DEFERRED
  regression guard
MUST NOT REPORT at BLOCKING: this AC, on the grounds that it is a diff property or
  could pass on a failed grep. Both observations are true and neither is a concrete
  failure here.
ALSO PRESENT, scoreable at BLOCKING: `task-migrate`'s AC — "the migration applies
  cleanly in CI" — names a gate the plan never establishes exists, and "cleanly" has
  no observable. A lens that reports ONLY the DEFERRED item and misses this has
  under-read; a lens that reports both at their correct severities has passed
  cleanly.
CONTRAST: this fixture and `should-flag/verifiability-absence-passes-on-crash.md`
  are the matched pair for this lens — the same weakness class, one blocking and one
  not, distinguished only by whether a concrete failure exists.
ASSUMES: nothing about the host repo.
-->

---
title: pin the parser dependency
created: 2026-07-29
---

## Tasks

## Task: pin the parser to 2.x

```yaml
id: task-pin
depends_on: []
files:
  - package.json
  - pnpm-lock.yaml
status: pending
```

`package.json` moves `@vendor/parser` from `^1.9.0` to `^2.1.0`. The lockfile is
committed alongside it.

**This already holds on the current branch** — the 1.x copy was removed when the
adapter landed, and `pnpm-lock.yaml` resolves a single `@vendor/parser@2.1.0` today.
The check below is therefore a **regression guard**, not a gate: it exists so a future
dependency change cannot silently reintroduce a second major version, which would
break the `instanceof` checks in the error classifier.

## Acceptance criteria

- `package.json` declares `@vendor/parser: ^2.1.0`.
- `grep -c "@vendor/parser@1" pnpm-lock.yaml` returns 0 — no 1.x copy is resolved.
- `pnpm install --frozen-lockfile` exits 0.

## Task: migrate the call sites

```yaml
id: task-migrate
depends_on: [task-pin]
files:
  - src/parse/classify.ts
  - test/parse/classify.spec.ts
status: pending
```

2.x renamed `ParseError.kind` to `ParseError.reason`. Every read of `.kind` becomes
`.reason`.

## Acceptance criteria

- No occurrence of `.kind` remains in `src/parse/`.
- The classifier maps every `reason` value to its internal category, asserted per
  value against the exported enum.
- The migration applies cleanly in CI.
