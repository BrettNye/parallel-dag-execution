<!--
FIXTURE: coverage-requirement-no-owner
LENS: coverage (plan)
EXPECTED: BLOCKING
SHAPE: spec + plan in one file, for compactness. Everything from `## Parent spec`
  to `## Tasks` is the FROZEN parent spec; everything after is the plan. Dispatch
  with both roles pointing here and say so. Ignore this comment block.
COVERS: R3 (retention purge) has no owning task. Three tasks cover R1, R2, and R4;
  none touches retention, and no task's `files:` includes a scheduler, a job, or a
  purge query. Every acceptance criterion goes green while rows are never purged —
  the #1 way a fully-green run ships an incomplete feature.
EXPECTED REPORT (substring match):
  R3
  no owning task
MUST NOT REPORT: that R2's AC is weak (that is `verifiability`), that `task-export`
  is oversized (that is `context-sufficiency`), or whether the cited paths exist
  (that is `grounding`). A requirement→task matrix is expected in the output.
ALSO PRESENT, scoreable: R1 is only PARTIALLY covered — `task-schema` adds the
  column but no task backfills existing rows, which R1's second sentence requires.
  Expected at BLOCKING or DEFERRED from `coverage` (either is defensible; silence
  is not).
ASSUMES: nothing about the host repo.
-->

---
title: soft-delete for exports
created: 2026-07-29
---

## Parent spec

### 1. Goal

Deleting an export hides it instead of destroying it, so a mistaken delete is
recoverable for a window.

### 2. Requirements

- **R1** — `exports` gains a nullable `deleted_at`. Existing rows backfill to `NULL`
  explicitly rather than relying on the column default.
- **R2** — `DELETE /api/exports/:id` sets `deleted_at` and returns `204`; it never
  removes the row.
- **R3** — Rows with `deleted_at` older than 30 days are purged permanently.
- **R4** — The export list excludes soft-deleted rows by default, and accepts
  `?includeDeleted=true` to include them.

### 3. Layer map

| Layer | Location |
|---|---|
| Migration | `db/migrations/` |
| API | `src/exports/` |

## Tasks

## Task: add the column

```yaml
id: task-schema
depends_on: []
files:
  - db/migrations/0044_exports_deleted_at.sql
status: pending
```

Adds `deleted_at timestamptz null` to `exports`.

## Acceptance criteria

- `\d exports` shows `deleted_at`, nullable, `timestamptz`.
- Applying the migration twice is a no-op.

## Task: soft-delete the route

```yaml
id: task-route
depends_on: [task-schema]
files:
  - src/exports/exports.controller.ts
  - src/exports/exports.repository.ts
  - test/exports.controller.spec.ts
status: pending
```

`DELETE /api/exports/:id` stamps `deleted_at` and returns `204`.

## Acceptance criteria

- After a delete, the row is still present and `deleted_at` is set.
- The response is `204` with no body.

## Task: filter the list

```yaml
id: task-list
depends_on: [task-schema]
files:
  - src/exports/exports.query.ts
  - test/exports.query.spec.ts
status: pending
```

The list query excludes soft-deleted rows unless `includeDeleted=true`.

## Acceptance criteria

- A soft-deleted row is absent from the default list and present with
  `?includeDeleted=true`.
- The flag defaults to false when omitted.
