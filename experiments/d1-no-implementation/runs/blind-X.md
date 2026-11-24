Review of review-X, 402d20b..26b3474 (plan excluded). Suites exit 0 (plan-state 225/0) but print four `fails + : arithmetic syntax error` (lines 515, 624, 680, 733). Ran gawk --posix for awk comparisons.
[Important] [tests] tests/plan-state/plan-state.test.sh:514-515 (+623-624, 679-680, 732-733) — rg -c prints nothing on zero matches; $((fails + )) errors every green run; without rg FAIL lines are never counted and suite exits 0 with failures.
[Important] [correctness] skills/writing-dag-plans/plan-state:56,78 — two review_rounds lines: round reads last, rewrites first; cap never fires and check passes (probed).
[Suggestion] [tests] tests/plan-state/plan-state.test.sh (T22) — no test of count surviving a restart (goal 4).
[Suggestion] [correctness] skills/writing-dag-plans/plan-state:223 — editverb tokenizes earlier paths; verb inside a path fires P1 (probed).
[Suggestion] [correctness] skills/writing-dag-plans/plan-state:201 — double-backtick spans yield no candidate (probed).
[Suggestion] [spec] skills/executing-dag-plans/quality-reviewer-prompt.md:117 (+spec :98, merged :106) — re-dispatch notes don't state the cap.
[Suggestion] [clarity] skills/executing-dag-plans/implementer-prompt.md:130 — paragraph splits colon from template; addressed to controller.
[Suggestion] [clarity] skills/writing-dag-plans/plan-format.md:262 — "written only by round" contradicts hand-written drafts allowed.
[Suggestion] [convention] skills/updating-dag-plans/SKILL.md:88 — finding-matching rule stated twice.
[Suggestion] [convention] skills/executing-dag-plans/SKILL.md:84 — ISSUES row restates exit-code handling.
TOTAL: 2 Important, 8 Suggestion
