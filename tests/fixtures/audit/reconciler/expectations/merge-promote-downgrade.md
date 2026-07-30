# EXPECTED — merge-promote-downgrade

The grading key for `../merge-promote-downgrade/`. **All paths below are relative to
that directory**, which is the tree the reconciler is given as its repo root.

It lives out here on purpose. The reconciler gets the case directory as its repo root
and has `Read` and `Glob`, so a key *inside* that tree is a guardrail made of a polite
request — and a reconciler that reasonably decides to look around would contaminate
its own run. As a sibling, it cannot.

Score against it after the run. Never pass it, or its path, into the prompt.

Inputs: `artifact.md`, `plan.md`, `code/`, and five lens reports —
`coverage`, `verifiability`, `grounding`, `design`, `charter`.

---

## Verdict

**NOT READY — 3 blocking.** More or fewer is a failure; the count is the fastest
signal that a merge, a promotion, or a downgrade went wrong.

## The three blocking findings

1. **R3 (audit row) has no owning task.** From `coverage`, upheld as-is. Nothing in
   `plan.md` owns it — verify this yourself rather than trusting the lens.
2. **`task-worker`'s retry AC is unfalsifiable.** From `verifiability`, upheld as-is.
3. **`RECOMPUTE_MAX_ATTEMPTS` will land as two copies that cannot be kept in sync.**
   **This must be a PROMOTION** — see below.

## Promotion (the headline check)

`design` reported the duplicate constant at **DEFERRED**, saying explicitly it could
not establish a drift mechanism: *"Whether the two copies can drift silently depends
on whether a shared import path between the worker and the web client is available,
and I cannot determine that from this artifact."*

`charter`'s enforcement map supplies exactly that missing fact: **no import path
exists** between `workers/*` and `apps/web/*`, so the two copies cannot be reconciled
by any compiler or lint check.

Neither lens could reach this alone. **The reconciler must combine them and promote to
BLOCKING**, and must log the promotion. Leaving it at DEFERRED is the primary
regression this fixture exists to catch.

## Contradiction — and the majority is wrong

Requirement: **does `applyRecompute` exist?**

| Lens | Verdict | Evidence |
|---|---|---|
| `coverage` | absent | one strategy — `grep -rn applyRecompute plan.md` |
| `verifiability` | absent | one strategy — `grep -rn applyRecompute workers/`, a directory that does not exist here |
| `grounding` | **present** | read at `code/handler.ts:15`, with signature, plus the `RecomputeJob` shape at `:6-9` |

Two lenses say absent, one says present. **`grounding` is correct** — the function is
at `code/handler.ts:15`. Both absence claims searched the wrong place: `plan.md` is
not the tree, and `workers/` does not exist in this fixture.

The reconciler must **read `code/handler.ts` itself**, side with the outnumbered
lens, and surface the contradiction explicitly. Resolving this by count — or quietly
dropping `grounding`'s row — is a failure.

Both wrong claims are **downgraded, not deleted**, and each appears in the log.

## Downgrade to STALE

`charter` reported **BLOCKING**: §5's docs obligation has no owning task.

`plan.md` has **`task-endpoints-doc`**, which owns `docs/reference/endpoints.md` and
carries two acceptance criteria. The finding cannot reach an implementer.

Expected: **STALE** (or DEFERRED), logged, citing `task-endpoints-doc`. A reconciler
that upholds this at BLOCKING has skipped the downstream check.

## Stale vs defect

- DEFECT: R3, the retry AC, the promoted constant.
- STALE: `charter`'s docs finding (handled by `task-endpoints-doc`).
- Neither: the two `applyRecompute` absence claims — those are **wrong**, not stale,
  and the distinction should be visible in the output.

## Downgrade log

Must be **non-empty** and contain at least: `coverage`'s absence claim,
`verifiability`'s absence claim, `charter`'s docs finding, and the `design` →
BLOCKING promotion (logged for symmetry). An empty log fails the fixture outright.

## No deletions

Every finding in every input report must appear somewhere in the output — blocking,
deferred, stale, contradiction, or log. Auditable count: **11 findings in** across
the five reports. Nothing may vanish.

## Solid — two clearances that must survive

Both are correct and must not be re-flagged:

- `verifiability`: `task-route`'s dedupe AC is the *right* shape — "returns the same
  job id" is the positive control that stops "enqueues nothing" passing on a crash.
- `grounding`: the worker imports the constant rather than redeclaring it
  (`code/handler.ts:4`), so the worker side of §3 is already sound. Only the web
  client's copy is at issue.

## Common wrong answers

| Output | What it means |
|---|---|
| 2 blocking | the promotion didn't happen |
| 4 blocking | `charter`'s docs finding wasn't checked against the plan |
| `applyRecompute` reported absent | resolved the contradiction by majority |
| Empty downgrade log | suppression is happening silently — the worst failure |
| Fewer than 11 findings accounted for | something was deleted |
