**ISSUES**

1. Requirement: The S8 row must filter to dirs with "≥3 files" (`detected_dirs`), exactly as in the spec text. | Actual: The committed S8 row says "Filter to dirs with ≥2 files (`detected_dirs`)." | Fix: In `/home/user/parallel-dag-execution/skills/writing-dag-plans/plan-quality.md`, change "≥2 files" to "≥3 files" in the S8 row.

Everything else matches the spec:
- The H9 row sits immediately after H8, and its text matches the spec.
- The S8 row sits immediately after S7. Apart from the threshold above, its text matches the spec.
- Detection algorithm steps 2 and 3 read H1-H9 and S1-S8, and no H1-H8 or S1-S7 reference remains in that list.
- The H9 refusal example and the S8 warning example are inside the existing code blocks, with the exact wording from the spec.
- No existing rows or sections were changed. The diff only adds lines, plus the two edited step lines.
- The six grep checks would pass. I did not run them, because the diff already contains each string.
