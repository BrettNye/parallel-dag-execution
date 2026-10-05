APPROVED. The diff to skills/updating-dag-plans/SKILL.md meets every step of the spec, with no over-build.

- **Step 1:** S1-S8 is changed to S1-S9 in the plan-quality.md bullet.
- **Step 2:** Both new rows are in the operations table with the spec's verbatim text.
- **Step 3:** The note on why `ready` is mutable for tier hints follows the table and matches the spec text.
- **Step 4:** The `running` refusal example for task-3.model_hint is added to the example refusals.
- **Step 5:** The new bullet is in Process step 6, with the enum re-validation (rules #7/#8), S9, and the "no structural re-validation" line.
- **Immutable-history invariant:** `running`, `done`, `failed` and `skipped` stay immutable. Tier hints and the plan-level default are mutable only on `pending` or `ready`.

I did not run the Step 6 grep or the Step 7 commit check. Only the diff was read.
