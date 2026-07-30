<!--
FIXTURE: s13-tautological-expected-value
RULE: S13 (tautological criterion)
EXPECTED: warn on task-backoff; do NOT warn on task-timeout or task-column
COVERS: the trigger plus BOTH of S13's suppressors. S13 is an LLM-judgment rule like
  S1 — there is no regex — so the honest fixture has to make the judgment call sharp
  rather than lexically obvious, and has to test both escape hatches, because a
  judgment rule with one tested suppressor will drift into over-firing.
  task-backoff — MUST WARN. `RETRY_SCHEDULE` is declared in THIS task's own
                 `## Implementation` block, and the criterion's expected value exists
                 nowhere else: `expect(recorded).toEqual(RETRY_SCHEDULE)` imports the
                 constant and asserts it equals itself. Green for [1,1,1], for [] on
                 an empty-array bug, and for any wrong schedule anyone ever writes.
                 The task is the only definer, so nothing pins the values.
  task-timeout — MUST NOT WARN, suppressor (a): the criterion states its expected
                 value as its OWN LITERAL (15_000, written in the criterion) and
                 drives the test from a fake clock rather than from the symbol.
                 Change the impl to 20_000 and the test fails — which is exactly the
                 falsifiability S13 is asking about.
  task-column  — MUST NOT WARN, suppressor (b): the assertion is about a
                 declaration's SHAPE, not its value, and the declaration genuinely IS
                 the requirement. "nullable timestamptz" cannot be restated as an
                 independent value; asserting the migration produced that column type
                 is the only thing there is to assert.
EXPECTED WARNING TEXT (substring):
  S13
  task-backoff
  RETRY_SCHEDULE
MUST NOT WARN: task-timeout, task-column.
SCORE S13 ONLY. No other rule should fire on any task here; if one does, that is a
  finding about the other rule, not about this fixture.
PRE-RUN HYPOTHESIS, recorded before this fixture was ever run, so that a later blind
  run can confirm or refute it independently rather than inherit it:
  I think S13's suppressor (a) is written too strictly and will over-fire on
  task-timeout. Its text requires that the criterion's literal "does not appear in the
  impl block" — but H7 REQUIRES an `## Implementation` block containing a
  minimum-viable impl, so a correctly-written task will normally show the real value
  there. `15_000` appears in both the criterion and the impl of task-timeout. Under a
  literal reading the suppressor fails and S13 fires on the correct form. Under the
  rule's rationale it must not: the test asserts against a hand-written literal, so
  changing the impl breaks the test, and that is the definition of not-tautological.
  If a blind run reports this, the clause should be rewritten to turn on WHAT THE
  ASSERTION REFERENCES (symbol vs literal) rather than on where the digits appear.
  Not pre-fixed: the whole lesson of the first run was that my re-reading finds
  nothing my blind runs find, so this is a prediction to be tested, not a conclusion.
FIRST RUN (2026-07-30): 3/3 graded verdicts correct — FIRE on task-backoff naming
  RETRY_SCHEDULE, no fire on task-timeout or task-column, each citing the intended
  suppressor. The hypothesis above was CONFIRMED INDEPENDENTLY and sharpened: the
  defect is not merely that suppressor 1 was too strict, it is that suppressor 1 and
  the trigger clause returned OPPOSITE verdicts on the same criterion, so the outcome
  depended on which sentence was read second. The trigger asks whether the value
  exists ONLY in the declaration — it does not, since the criterion states 15000 — so
  the trigger never fires; suppressor 1's "does not appear in the impl block" arm
  fails, leaving the flag standing. Rewritten to turn on what the assertion
  REFERENCES (literal vs declaration), which is what the rule always meant.
  The run also surfaced three defects outside S13, all fixed:
  - S12's token list omitted toBe(false) / toBeFalsy / not.toBe(true), despite the
    rule having just widened its match scope specifically to see code-level tokens.
    task-timeout's `expect(signal.aborted).toBe(false)` was visible and ignored.
  - S12 matched `is null` but not `has null` / `remains null`. A one-word gap, and the
    same under-firing family as the passive-voice bug fixed in the previous run.
  - "fire once per task" was stated for S12 only, leaving the warning count undefined
    for S13-S15 on a task with several offending criteria.
  TWO FIXTURE DEFECTS FIXED, both reported as outside-S13 observations:
  - task-column's second bullet ("An existing ledger row has voided_at null") was
    vacuous on an empty table — it never said a row was seeded first, so a test
    querying zero rows passed. Restated positive-with-control. This also mattered
    mechanically: the new `has ... null` pattern would have fired S12 on a
    MUST-NOT-WARN task, so the fixture and the rule had to move together.
  - task-timeout's first bullet folded meta-commentary about how the test must be
    authored into the criterion, over-constraining the implementation. Trimmed.
KNOWN AND DELIBERATE: task-backoff's "escalating" property stays unasserted even
  after the tautology is cured — [5, 5, 5] satisfies both criteria. That is a true
  limit of S13, worth leaving visible: S13 asks whether a criterion CAN fail, not
  whether it asserts the right thing.
-->

---
title: retry backoff, request timeout, void ledger column
created: 2026-07-30
---

```mermaid
flowchart TD
    task-backoff["task-backoff"]
    task-timeout["task-timeout"]
    task-column["task-column"]
```

## Tasks

## Task: retry backoff schedule

```yaml
id: task-backoff
depends_on: []
files:
  - src/retry/backoff.ts
  - test/retry/backoff.spec.ts
status: pending
```

Failed jobs retry on a fixed escalating backoff.

## Implementation

```typescript
// src/retry/backoff.ts
export const RETRY_SCHEDULE = [1_000, 5_000, 30_000];

export function delayFor(attempt: number): number {
  return RETRY_SCHEDULE[attempt] ?? RETRY_SCHEDULE.at(-1)!;
}
```

```typescript
// test/retry/backoff.spec.ts
it('escalates across attempts', () => {
  const recorded = [0, 1, 2].map(delayFor);
  expect(recorded).toEqual(RETRY_SCHEDULE);
});
```

## Acceptance criteria

- The recorded delays for attempts 0, 1 and 2 match `RETRY_SCHEDULE`, asserted with
  `expect(recorded).toEqual(RETRY_SCHEDULE)`.
- An attempt past the end of the schedule reuses the final delay rather than throwing
  or returning `undefined`.

Test file: `test/retry/backoff.spec.ts`.

## Task: request timeout

```yaml
id: task-timeout
depends_on: []
files:
  - src/http/timeout.ts
  - test/http/timeout.spec.ts
status: pending
```

Outbound requests abort rather than hanging.

## Implementation

```typescript
// src/http/timeout.ts
export const REQUEST_TIMEOUT_MS = 15_000;

export function withTimeout(signal: AbortSignal, clock: Clock): AbortSignal {
  // aborts the returned signal REQUEST_TIMEOUT_MS after subscription
}
```

```typescript
// test/http/timeout.spec.ts
it('aborts a request still in flight at 15 seconds', () => {
  const clock = fakeClock();
  const signal = withTimeout(new AbortController().signal, clock);
  clock.advance(14_999);
  expect(signal.aborted).toBe(false);
  clock.advance(2);
  expect(signal.aborted).toBe(true);
});
```

## Acceptance criteria

- A request still in flight at **15000 ms** aborts, and one at **14999 ms** has not:
  both bounds are asserted against those literals, written here rather than read from
  `REQUEST_TIMEOUT_MS`, so changing the implementation's timeout fails the test.
- The abort reason is a `TimeoutError`, not a bare `AbortError`, so a caller can tell a
  timeout from a user cancellation.

Test file: `test/http/timeout.spec.ts`.

## Task: void ledger column

```yaml
id: task-column
depends_on: []
files:
  - migrations/0042_void_ledger.sql
  - test/migrations/0042_void_ledger.spec.ts
status: pending
```

Ledger rows can be voided without being deleted.

## Implementation

```sql
-- migrations/0042_void_ledger.sql
ALTER TABLE ledger_entry ADD COLUMN voided_at timestamptz NULL;
```

```typescript
// test/migrations/0042_void_ledger.spec.ts
it('adds a nullable timestamptz', async () => {
  const col = await columnMeta('ledger_entry', 'voided_at');
  expect(col).toMatchObject({ dataType: 'timestamp with time zone', isNullable: 'YES' });
});
```

## Acceptance criteria

- After the migration runs, `ledger_entry.voided_at` exists with data type
  `timestamp with time zone` and is nullable, read back from `information_schema`
  rather than from the migration text.
- A ledger row seeded **before** the migration runs is still found afterwards, with its
  `amount` intact and its `voided_at` null — the row being found is the control, so an
  empty table or a failed seed fails the case rather than satisfying it.

Test file: `test/migrations/0042_void_ledger.spec.ts`.
