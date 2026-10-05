APPROVED

I read the diff for commit a5248e9 and checked each step of the spec.

- **Plan-level note (Step 3):** The `default_review_mode` note is present with the specified wording, placed after the existing default hints note.
- **Per-task schema (Step 4):** The `review_mode: merged` line is in the YAML schema block after `quality_reviewer_hint`, with the specified comment text.
- **Resolution section (Step 5):** `## Review-mode resolution` follows §Tier resolution. It contains the `resolve_review_mode` pseudocode with real fences, the split and merged bullets, the quality_reviewer tier rule, the note that `spec_reviewer_hint` is unused when merged, and the note that the per-task value wins.
- **Validation rules (Step 6):** Rules #9 and #10 are appended with the exact specified text.
- **Should-refuse fixtures (Step 1):**
  - `bad-task-review-mode-typo.md` has `review_mode: combined` and the specified rule #9 EXPECTED line.
  - `bad-plan-default-typo.md` has `default_review_mode: both` and the specified rule #10 EXPECTED line.
- **Should-pass fixtures (Step 7):**
  - `clean-no-review-mode.md` has no review_mode fields.
  - `clean-plan-level-merged.md` has a merged plan default only.
  - `clean-per-task-merged.md` has `review_mode: merged` on the task only.
  - `clean-hybrid.md` has a merged default and `review_mode: split` on the task.
  - Each has the specified EXPECTED comment on line 1.
- **Over-build:** None. The commit touches only the 7 listed files, and the changes are limited to the specified content. The extra line after rules 9/10 about rules #7/#8 was already in the file.
