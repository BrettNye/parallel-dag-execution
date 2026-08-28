<!--
FIXTURE: ambiguity-plan-unfalsifiable-requirement
LENS: ambiguity (plan)
EXPECTED: BLOCKING
SHAPE: plan audit — parent spec in this file under `## Parent spec`, plan under
  `## Tasks`. Dispatch with both roles pointing at this file. Ignore this comment
  block.
COVERS: R2 requires that a flagged post escalate to a human moderator "whenever
  escalation is warranted" — a guard whose condition no observation could
  contradict, because any moderator action or inaction can be described
  afterward as warranted or not. No test can ever fail it. `task-escalate`
  transcribes the clause verbatim, both in its body and as its sole acceptance
  criterion, without resolving it into a concrete trigger (a score threshold, a
  report count, a keyword match). An implementer reading only `task-escalate`
  has no observable event to build against and would invent whatever default
  seemed plausible; a different implementer would invent a different one, and
  both would satisfy the criterion equally — the plan inherited an unfalsifiable
  ask and shipped it unresolved.
EXPECTED REPORT (substring match):
  unfalsifiable
  no observation
MUST NOT REPORT: whether the frozen spec's decision to require human escalation
  at all was correct (that is relitigation, explicitly out of this lens's
  scope), or whether `task-escalate`'s named paths exist (that is `grounding`).
ALSO PRESENT: none declared until the gate run reconciles this header.
ASSUMES: nothing about the host repo.
-->

---
title: moderation escalation
created: 2026-07-29
---

## Parent spec

### 1. Goal

Flag potentially harmful posts for human review without blocking legitimate
content outright.

### 2. Requirements

- **R1** — A post scoring at or above `0.8` on the moderation classifier is
  flagged and hidden from public view pending review.
- **R2** — A flagged post escalates to a human moderator whenever escalation is
  warranted.

### 3. Layer map

| Layer | Location |
|---|---|
| Classifier hook | `src/moderation/score.ts` |
| Queue | `src/moderation/queue.ts` |

### 4. Out of scope

Automated appeals. Moderator tooling beyond the queue itself.

## Tasks

## Task: score and flag

```yaml
id: task-score
depends_on: []
files:
  - src/moderation/score.ts
  - test/moderation/score.spec.ts
status: pending
```

Runs the classifier on new posts and flags any scoring at or above `0.8`.

## Acceptance criteria

- A post scored `0.8` or above is flagged and excluded from the public feed.
- A post scored below `0.8` is unaffected.

## Task: escalate flagged posts

```yaml
id: task-escalate
depends_on: [task-score]
files:
  - src/moderation/queue.ts
  - test/moderation/queue.spec.ts
status: pending
```

Enqueues a flagged post for a human moderator whenever escalation is warranted.

## Acceptance criteria

- A flagged post escalates to a human moderator whenever escalation is
  warranted.
