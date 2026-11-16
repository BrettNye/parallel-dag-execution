# Blind review scores (2026-11-16)
Reviewer: fresh general-purpose subagent per branch, Opus 5.5, plan file excluded from the diff, neutral detached worktree. Key: blind-key.txt.

| Arm | Label | Important | Suggestion | Convention slips |
|---|---|---|---|---|
| A  | Y | 1 | 9 | 1 |
| B  | X | 2 | 8 | 2 |
| B0 | Z | 2 | 8 | 0 |

Important findings:
- A: quoted `review_rounds: "2"` passes rule 15 but is never rewritten; cap never fires.
- B: `rg -c` empty count breaks the suite's tallies (same bug the hidden check found); duplicate `review_rounds` lines defeat the cap.
- B0: `./` in `files:` not normalized, so a task's own file gets a P3 error; sentence-final strip test cannot fail.

Shared across all three: reviewer re-dispatch prompts never mention the cap (Suggestion in all three). The `./` normalization bug was found in A (Suggestion) and B0 (Important), not reported for B.
Decision rule line "B's Important <= A's": 2 vs 1, FAILS.
