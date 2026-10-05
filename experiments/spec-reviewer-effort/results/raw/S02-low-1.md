ISSUES

1. Requirement: the "Modify review mode" row must say "Re-validate enum (`merged | split`, rule #9)". | Actual: the row in /home/user/parallel-dag-execution/skills/updating-dag-plans/SKILL.md says `merged | split | auto`, which adds an `auto` value the spec doesn't include (over-build). | Fix: change the enum text in that row to `merged | split`.

Everything else matches the spec:
- S1-S9 is changed to S1-S10.
- Both new operation rows are present, and the `default_review_mode` row is verbatim.
- The `ready` note is added after the table with the required wording. It is its own blockquote headed "Why `ready` is mutable for `review_mode`", which is acceptable.
- The Process step 6 bullet is verbatim.
