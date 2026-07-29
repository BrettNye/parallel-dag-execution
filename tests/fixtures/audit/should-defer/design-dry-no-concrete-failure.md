<!--
FIXTURE: design-dry-no-concrete-failure
LENS: design (spec)
EXPECTED: DEFERRED (finding the duplication is correct; BLOCKING on it is the regression)
COVERS: the severity gate. Two DRY situations, deliberately contrasted:
  §3  duplicates a formatting helper across two files in ONE runtime with a shared
      import path available. Real duplication, no concrete failure → DEFERRED.
  §4  duplicates a constant across TWO runtimes with no shared import path
      possible, so the copies WILL drift silently → that names a concrete failure,
      so BLOCKING is correct there.
  A lens that blocks on §3, or that defers §4, has failed this fixture.
EXPECTED REPORT (substring match):
  DEFERRED
  no concrete failure
MUST NOT REPORT: §3 as BLOCKING. "This is duplicated" and "this would be cleaner"
  are never sufficient.
ASSUMES: a repo where apps/api and apps/web are separate runtimes with no shared
  import path between them, and where libs/shared is importable by both.
-->

---
title: period summary formatting
created: 2026-07-29
---

# Period summary formatting

## 1. Goal

Render a period summary consistently in the API's PDF export and in the web UI.

## 2. Data

`GET /api/periods/:id/summary` returns `{ totalHours, overtimeHours, rate }`.

## 3. Formatting helper

Both `apps/api/src/reporting/pdf-renderer.ts` and
`apps/api/src/reporting/csv-renderer.ts` will define their own
`formatHours(n: number): string` returning one decimal place followed by `" h"`.
Keeping them local avoids adding an import between the two renderers.

## 4. Threshold constant

The overtime threshold `40` is needed in two places:
`apps/api/src/reporting/pdf-renderer.ts` for the PDF, and
`apps/web/src/app/period/summary.component.ts` to style the value red once
exceeded. Each will declare `const OVERTIME_THRESHOLD = 40;` locally.

## 5. Layer map

| Layer | Location |
|---|---|
| API renderers | `apps/api/src/reporting/` |
| Web summary | `apps/web/src/app/period/` |
| Shared libs | `libs/shared/` |

## 6. Acceptance criteria

- The PDF and CSV render `12.5 h` for 12.5 hours.
- The web summary styles the overtime value red above the threshold.
