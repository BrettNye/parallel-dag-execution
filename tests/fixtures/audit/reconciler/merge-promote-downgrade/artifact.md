---
title: period recompute trigger
created: 2026-07-29
---

# Manual period recompute

## 1. Goal

Let an operator re-run the calculation for one closed period without reopening it.

## 2. Requirements

- **R1** — `POST /api/periods/:id/recompute` enqueues a recompute job and returns
  `202` with the job id.
- **R2** — A period already enqueued is not enqueued twice; the second call returns
  the existing job id.
- **R3** — Every recompute writes an audit row naming the operator and the period.

## 3. Retry limit

`RECOMPUTE_MAX_ATTEMPTS = 3`, referenced by the worker that runs the job and by the
web client that renders "attempt N of 3" in the job drawer.

## 4. Layer map

| Layer | Location |
|---|---|
| API route | `apps/api/src/periods/` |
| Worker | `workers/recompute/src/` |
| Web client | `apps/web/src/app/periods/` |

## 5. Docs

`docs/reference/endpoints.md` gains a row for the new route.

## 6. Out of scope

Scheduling recurring recomputes. Reopening a closed period.
