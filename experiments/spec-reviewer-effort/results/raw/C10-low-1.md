APPROVED. Every requirement in the spec is met, and I found no over-build in the listed files.

- **Plan-level default (Step 3):** the `default_review_mode` note is in `plan-format.md` with the specified text.
- **Per-task field (Step 4):** the `review_mode` line is in the per-task YAML schema block, right after `quality_reviewer_hint`, with the specified text.
- **Resolution section (Step 5):** `## Review-mode resolution` sits right after Tier resolution. It has the resolve pseudocode, the split and merged bullets, the quality_reviewer-tier rule for merged, and the notes on unused `spec_reviewer_hint` and per-task override.
- **Validation rules (Step 6):** rules #9 and #10 are appended after #8 with the specified wording.
- **Refuse fixtures (Step 1):** `bad-task-review-mode-typo.md` has `review_mode: combined` and the rule #9 EXPECTED comment. `bad-plan-default-typo.md` has `default_review_mode: both` and the rule #10 EXPECTED comment.
- **Pass fixtures (Step 7):** the four clean fixtures have the correct EXPECTED comments and the right fields. `clean-no-review-mode` has no review_mode anywhere, `clean-plan-level-merged` has only the plan-level default, `clean-per-task-merged` has only the per-task field, and `clean-hybrid` has the default `merged` plus per-task `split`.

The commit touches only the 7 listed files.

The `should-warn/s10-*` fixtures also contain `review_mode` text. They are outside this task's file list and this commit did not touch them.
