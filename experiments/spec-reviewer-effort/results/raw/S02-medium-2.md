ISSUES

1. Requirement: The "Modify review mode" row must say "Re-validate enum (`merged | split`, rule #9)." | Actual: the row says "`merged | split | auto`, rule #9", which adds an `auto` value the spec does not list. | Fix: In /home/user/parallel-dag-execution/skills/updating-dag-plans/SKILL.md, change the enum text in that row to `merged | split`.

2. Requirement: After the table, add the sentence "`ready` is mutable for `review_mode` for the same reason as tier hints — it doesn't interact with the parallelism contract; the next tick reads fresh state and dispatches the resolved review mode. `running`/`done`/`failed`/`skipped` remain immutable." | Actual: the sentence is present, but it sits in a new blockquote headed "**Why `ready` is mutable for `review_mode`:**". The spec has no such heading. | Fix: Optional and minor. Drop the bold heading prefix and use the sentence as the spec words it. I count this as an over-build only if you read the spec strictly.

All other requirements are met:
- The S1-S9 to S1-S10 change in §Required reading is done.
- Both operation rows are present and match the spec apart from issue 1.
- The §Process step 6 bullet matches the spec text.
- `ready` stays mutable for `review_mode`, and running/done/failed/skipped stay immutable.
