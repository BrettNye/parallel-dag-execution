<!--
FIXTURE: coverage-complete-no-overbuild
LENS: coverage (plan)
EXPECTED: no finding
SHAPE: spec + plan in one file. Everything from `## Parent spec` to `## Tasks` is the
  FROZEN parent spec; everything after is the plan. Ignore this comment block.
COVERS: silence as the correct answer, in both directions at once.
  - UNDER-BUILD: none. All four requirements have an owning task, including the two
    that span surfaces — R2 needs both the writer and the reader, and both are owned.
  - OVER-BUILD: none. Every task deliverable traces to a numbered requirement, and
    §5's out-of-scope items (bulk edit, audit trail) appear in no task's `files:`.
  - The trap: R4 looks unowned on a filename scan, because no task is *named* for
    retries. It is owned inside `task-worker`, whose body and second AC carry it. A
    lens that matches requirements to task TITLES rather than task CONTENT reports a
    false gap here. That false gap is the regression this fixture exists to catch.
EXPECTED REPORT (substring match):
  No blocking findings
MUST NOT REPORT: R4 as unowned; `task-worker` as oversized (that is
  `context-sufficiency`); the retry AC's strength (that is `verifiability`); the
  `depends_on` shape (that is `dag-integrity`). A requirement→task matrix showing
  four covered requirements is the expected output, with no findings under it.
ASSUMES: nothing about the host repo.
-->

---
title: webhook delivery
created: 2026-07-29
---

## Parent spec

### 1. Goal

Deliver an event to a customer's webhook URL, and let them see whether it arrived.

### 2. Requirements

- **R1** — A registered endpoint is stored with its URL and a signing secret.
- **R2** — Each delivery attempt is recorded with its status code and timestamp, and
  the customer can list attempts for one event.
- **R3** — Requests carry an `X-Signature` header, HMAC-SHA256 over the raw body
  using the endpoint's secret.
- **R4** — A failed delivery is retried with exponential backoff, up to five attempts.

### 3. Layer map

| Layer | Location |
|---|---|
| Migration | `db/migrations/` |
| Worker | `src/delivery/` |
| API | `src/webhooks/` |

### 4. Reference

Mirror `src/mailer/worker.ts` for the backoff loop.

### 5. Out of scope

Bulk endpoint editing. A customer-facing audit trail of secret rotations.

## Tasks

## Task: endpoints and attempts tables

```yaml
id: task-schema
depends_on: []
files:
  - db/migrations/0071_webhook_endpoints.sql
  - db/migrations/0072_webhook_attempts.sql
status: pending
```

`webhook_endpoints` (url, secret) and `webhook_attempts` (event_id, endpoint_id,
status_code, attempted_at).

## Acceptance criteria

- Both tables exist with the stated columns and types.
- `webhook_attempts.event_id` is indexed, since attempts are always read by event.

## Task: sign and deliver

```yaml
id: task-worker
depends_on: [task-schema]
files:
  - src/delivery/deliver.ts
  - src/delivery/sign.ts
  - test/delivery/deliver.spec.ts
  - test/delivery/sign.spec.ts
status: pending
```

Signs the request and performs the delivery, writing one `webhook_attempts` row per
attempt. Retries a failed attempt with exponential backoff, capped at five attempts
total — mirroring the loop in `src/mailer/worker.ts`.

## Acceptance criteria

- `X-Signature` is HMAC-SHA256 of the raw body under the endpoint's secret, asserted
  against a known-good vector rather than against the implementation's own output.
- A permanently-failing endpoint produces exactly five `webhook_attempts` rows and
  no sixth, with the recorded delays increasing.
- Each attempt's row carries the returned status code and its timestamp.

## Task: list attempts

```yaml
id: task-api
depends_on: [task-schema]
files:
  - src/webhooks/attempts.controller.ts
  - test/webhooks/attempts.controller.spec.ts
status: pending
```

`GET /api/events/:id/attempts` returns the attempts for one event, newest first.

## Acceptance criteria

- Returns every attempt for the event, ordered by `attempted_at` descending, with a
  stable tie-break on `id`.
- Returns an empty array — not a 404 — for an event with no attempts yet.
