ISSUES

1. Requirement: The "Modify review mode" row must say "Re-validate enum (`merged | split`, rule #9)." | Actual: the row says `merged | split | auto`, which adds an `auto` value the spec doesn't define. | Fix: Change the enum text in that row to `merged | split`.

Everything else matches the spec.
- The S1-S9 reference is now S1-S10.
- The `default_review_mode` row is present with the spec text.
- The Process step 6 bullet is present and matches.
- The `ready`-mutability note is present, as a blockquote after the table. It says `ready` is mutable for `review_mode` for the same reason as tier hints. It also says `running`/`done`/`failed`/`skipped` remain immutable.

The new text is in /home/user/parallel-dag-execution/skills/updating-dag-plans/SKILL.md.
