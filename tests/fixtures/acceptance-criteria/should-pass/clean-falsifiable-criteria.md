<!--
FIXTURE: clean-falsifiable-criteria
RULE: S12, S13, S14, S15 — all four
EXPECTED: no warning from any of the four
COVERS: silence as the correct answer, with each rule's trigger words PRESENT but in
  its legitimate form. This is the fixture that fails if the rules are written as
  keyword greps rather than as shape checks with suppressors.
  - S12 trigger present: "issues no PATCH" — suppressed by the sibling bullet
    asserting the same spy sees exactly one PATCH on the save path.
  - S13 trigger present: an expected value asserted for a constant the task defines —
    suppressed because the criterion states the value as its own literal AND checks a
    known-good vector rather than importing the constant.
  - S14 trigger present: "every" — suppressed because the iteration set is the
    exported array and the assertion is count-equality.
  - S15 trigger present: "unchanged" — suppressed because it is stated
    positive-with-control (the row IS found, with its other fields intact), and the
    file is not self-scoped.
MUST NOT WARN: any task, any rule. A single warning here means a rule is matching
  words instead of shapes, which is the failure mode that gets a soft rule ignored.
FIRST RUN (2026-07-30) FIXED TWO DEFECTS IN THIS FIXTURE:
  - H7 (hard rule): `## Implementation` had ONE fenced block; H7 requires at least
    two (impl + failing test) for any task without `is_wiring_task: true`. The plan
    would have been REFUSED before a single soft rule ran, so a green result here
    proved nothing. A failing-test block was added.
  - The `Promise<number>` return was asserted by no criterion, so an implementer
    could return the wrong count and pass every bullet. The added test block pins it.
  Both were reported by the run as defects outside S12-S15's remit — which is the
  fixture suite working as intended: the graded verdicts were right, and the free
  observations were worth more than the grade.
-->

---
title: retention purge
created: 2026-07-30
---

```mermaid
flowchart TD
    task-purge["task-purge"]
```

## Tasks

## Task: purge expired rows

```yaml
id: task-purge
depends_on: []
files:
  - src/purge/purge.ts
  - test/purge/purge.spec.ts
status: pending
```

Deletes rows whose `deleted_at` is older than the retention window, leaving newer
soft-deleted rows in place.

## Implementation

```typescript
// src/purge/purge.ts
import { RETENTION_DAYS } from './config.js';
import { PURGE_STATUSES } from './statuses.js';

export async function purge(now: Date, db: Db): Promise<number> {
  // delete where deleted_at < now - RETENTION_DAYS; returns rows deleted
}
```

```typescript
// test/purge/purge.spec.ts
it('deletes past the window and keeps the survivor', async () => {
  await seed([{ id: 'old', deleted_at: daysAgo(31) }, { id: 'new', deleted_at: daysAgo(29) }]);
  expect(await purge(NOW, db)).toBe(1);
  expect(await ids()).toEqual(['new']);
});
```

## Acceptance criteria

- A row stamped 31 days ago is gone after `purge` runs, and a row stamped 29 days ago
  is still present with all of its other fields unchanged — both asserted by reading
  the rows back, so the survivor's presence is the control for the deletion.
- `RETENTION_DAYS` is **30**, asserted against the literal `30` written in this
  criterion, not against the imported constant.
- Every status in `PURGE_STATUSES` is handled: the test iterates the exported array
  and asserts the handler map's key count equals its length, so a status added later
  fails rather than being skipped.
- A purge run that finds nothing to delete issues no DELETE — asserted with the same
  db spy that, in the preceding case, sees exactly one DELETE.
- A db error during purge propagates rather than being swallowed
  (`await expect(purge(...)).rejects.toThrow()`).

Test file: `test/purge/purge.spec.ts`.
