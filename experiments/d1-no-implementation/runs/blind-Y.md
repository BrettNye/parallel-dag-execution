Review of review-Y, 402d20b..1757d4d (plan excluded). Suites pass under bash/dash/gawk (plan-state 200/0, rdp 91/0, commit-safe both).
[Important] [correctness] skills/writing-dag-plans/plan-state:104,191-200,368 — quoted review_rounds: "2" passes rule 15 via unq() but emit's sub doesn't match; round prints 3 and exits 0 without writing, so the cap never fires (reproduced).
[Suggestion] [spec] skills/executing-dag-plans/quality-reviewer-prompt.md:117 — re-dispatch note doesn't mention round/cap.
[Suggestion] [spec] skills/executing-dag-plans/spec-reviewer-prompt.md:100 — same.
[Suggestion] [spec] skills/executing-dag-plans/merged-reviewer-prompt.md:106 — same.
[Suggestion] [clarity] skills/executing-dag-plans/SKILL.md:94 — "failed (after auto-retry)" omits review cap and no-verdict.
[Suggestion] [clarity] skills/executing-dag-plans/implementer-prompt.md:128-130 — new paragraph splits a colon from its template.
[Suggestion] [correctness] skills/writing-dag-plans/plan-state:505 — awk exit status lost in pipeline; failure turns into false P2/P3.
[Suggestion] [correctness] skills/writing-dag-plans/plan-state:211,239 — ./ in files: not normalized; false P1 (reproduced), possible false P3.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh:455,459,565 — new cases use rg (~8 times) — use grep.
[Suggestion] [convention] skills/executing-dag-plans/SKILL.md:39 — P1–P4 defined in three places; CLAUDE.md "once".
TOTAL: 1 Important, 9 Suggestion
