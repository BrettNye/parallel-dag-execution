APPROVED. Commit bd586f9 changes only skills/updating-dag-plans/SKILL.md, and it matches the spec in both directions.

- **Step 1:** the plan-quality.md bullet now reads S1-S9 instead of S1-S8.
- **Step 2:** both table rows (modify tier hint, modify plan-level default hint) are appended after the `Rewire depends_on:` row. Their text matches the spec verbatim.
- **Step 3:** the note on why `ready` is mutable for tier hints sits after the table, and its wording matches the spec.
- **Step 4:** the `running` refusal example for task-3.model_hint is added to §Example refusals, and the text matches the spec.
- **Step 5:** step 6 has the new bullet for the tier-hint and plan-level default-hint ops. It re-validates the enum (rules #7/#8), runs S9, and says no structural re-validation is needed.
- **Immutable-history invariant:** the invariant still holds. Tier-hint edits are permitted only on `pending` or `ready`. The plan-default row says to refuse if every task is already immutable, and `running`, `done`, `failed` and `skipped` stay immutable.
- **Over-build:** I found none. Every changed line traces to a requirement.

I did not run the Step 6 grep or the Step 7 commit command. I compared the diff against the spec text only.
