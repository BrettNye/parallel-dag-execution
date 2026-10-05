ISSUES

1. Requirement: The "Modify review mode" row must read "Re-validate enum (`merged | split`, rule #9)". Actual: the row says `merged | split | auto`, which adds an `auto` value that the spec doesn't include. Fix: in the new `review_mode` row in §Operations supported, change `merged | split | auto` to `merged | split`.

2. Requirement: the note after the table is the sentence "`ready` is mutable for `review_mode` for the same reason as tier hints — it doesn't interact with the parallelism contract; the next tick reads fresh state and dispatches the resolved review mode. `running`/`done`/`failed`/`skipped` remain immutable." Actual: the sentence is present word for word, but it sits in a new blockquote headed "**Why `ready` is mutable for `review_mode`:**", which the spec doesn't ask for. Fix: this is minor. Drop the "Why ... :" bold prefix and use the spec text as written. Leave it as is only if the formatting is acceptable.

Everything else matches the spec.
- The S1-S9 to S1-S10 change in §Required reading is made.
- The `default_review_mode` row matches the spec.
- The §Process step 6 bullet matches the spec.
- Only `skills/updating-dag-plans/SKILL.md` was changed.
