<!--
FIXTURE: context-sufficiency-bare-pointer
LENS: context-sufficiency (plan)
EXPECTED: BLOCKING
SHAPE: spec + plan in one file. Everything from `## Parent spec` to `## Tasks` is the
  FROZEN parent spec; everything after is the plan. Ignore this comment block.
COVERS: two defects of the same class — a task body that cannot be executed from
  itself.
  (a) `task-normalize`'s acceptance criteria are BARE POINTERS: "per spec §2.2" and
      "upholds the invariant in §3". The executor's reviewers treat the task body AS
      the binding spec and never see the parent spec, so neither criterion is
      verifiable at review time, and the implementer must guess the rule.
  (b) `task-adapters`'s implementation ELIDES SIBLINGS: "the other three adapters
      follow the same shape". Three adapters are named nowhere, so the implementer
      chooses which three, and a reviewer cannot tell whether any are missing.
EXPECTED REPORT (substring match):
  pointer
  §2.2
  elide
MUST NOT REPORT: whether the normalization rule is correct (out of scope for every
  lens — the spec is frozen), missing `depends_on` edges (that is `dag-integrity`),
  or requirement coverage (that is `coverage`).
ALSO PRESENT, scoreable: `task-adapters` declares `files:` for one adapter only
  (`csv.adapter.ts`) while its body describes four. Expected at BLOCKING from
  `context-sufficiency` (the stated scope cannot accommodate the described work) and
  independently from `dag-integrity` (understated `files:`).
ASSUMES: nothing about the host repo.
-->

---
title: feed normalization
created: 2026-07-29
---

## Parent spec

### 1. Goal

Normalize inbound partner feeds to one internal row shape before persistence.

### 2. Normalization

#### 2.1 Field mapping

Partner column names map to internal names via a per-partner table.

#### 2.2 Value rules

Trim surrounding whitespace. Empty string becomes `null`. Dates parse as
`YYYY-MM-DD` and reject anything else. Numbers reject thousands separators rather
than stripping them.

### 3. Invariant

A normalized row is byte-identical regardless of which adapter produced it, so two
partners submitting the same data yield the same stored row.

### 4. Adapters

Four inbound formats: CSV, TSV, fixed-width, and JSON-lines.

## Tasks

## Task: the normalizer

```yaml
id: task-normalize
depends_on: []
files:
  - src/feeds/normalize.ts
  - test/feeds/normalize.spec.ts
status: pending
```

The shared normalization pass every adapter calls before handing rows to the writer.

## Acceptance criteria

- Values are normalized per spec §2.2.
- The output upholds the invariant in §3.
- `pnpm test src/feeds` passes.

## Task: the adapters

```yaml
id: task-adapters
depends_on: [task-normalize]
files:
  - src/feeds/csv.adapter.ts
status: pending
```

Each adapter parses its format into raw rows and calls the normalizer.

## Implementation

```typescript
// src/feeds/csv.adapter.ts
export function parseCsv(input: string): RawRow[] {
  // split on newlines, split on commas, honour quoted fields
}
```

The other three adapters follow the same shape.

## Acceptance criteria

- Each adapter produces `RawRow[]` and calls the normalizer exactly once per row.
- All four formats round-trip the same fixture to an identical normalized row.
