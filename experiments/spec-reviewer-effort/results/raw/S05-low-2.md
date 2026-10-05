ISSUES

Requirement: S8 row must match the spec text, which filters to dirs with "≥3 files" (`detected_dirs`).
Actual: the S8 row in /home/user/parallel-dag-execution/skills/writing-dag-plans/plan-quality.md says "Filter to dirs with ≥2 files".
Fix: change "≥2 files" to "≥3 files" in the S8 row.

Everything else meets the spec:
- The H9 row sits immediately after H8, and its text matches the spec.
- The S8 row sits immediately after S7. Apart from the ≥2 threshold it matches the spec, and it covers Branch A, Branch B, both exemptions and the wiring-task exemption.
- Detection algorithm steps 2 and 3 now read H1-H9 and S1-S8.
- The H9 refusal example and the S8 warning example are added exactly as given, inside the existing code blocks.
- The diff touches no existing rows or sections.

I did not run the six grep verification commands. From the diff, all six patterns appear in the new text, so they should exit 0.
