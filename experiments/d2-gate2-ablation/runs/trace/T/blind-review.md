I reviewed c57de12..2fa119f against docs/superpowers/specs/2026-11-17-named-tests-design.md, leaving out the plan file. I ran all six suites at 2fa119f, using Git Bash: every one exits 0. Counts: audit-stats 8/0, concurrent-commit PASS, stale-lock PASS, plan-state 257/0, resolve-declared-paths 91/0, verify-tests 48/0. I modified nothing.

Most of the spec is delivered and correct: the rule 16/17 checks, `base_sha` on `set running`, the `plan-state tests` record and its exit-2 order, every step of verify-tests, the label precedence and tail order, the prompt and skill wiring, `.gitattributes` and the CLAUDE.md helper list. A suite line ending in CR and trailing spaces is still matched, and the task's test file keeps its finished content in the before tree.

[Important] [correctness] skills/executing-dag-plans/SKILL.md:76 — The text assumes the 600000 ms Bash timeout kills verify-tests. The branch's own probe (verify-tests:16-19) found the tool moves the command to the background without a signal; seen again in this review after 180 s. The controller has no rule for a backgrounded check, so verify-tests is not bounded — fix: a Bash result reporting the command was moved to the background or timed out counts as exit 2 (halt), and stop it with TaskStop.
[Important] [tests] tests/verify-tests/verify-tests.test.sh:76-89 — `scen` always commits the suite file before `base_sha`, so no case depends on the task's test files keeping their HEAD content in the before tree (spec step 6). An implementation that put test files back to `base_sha` would still pass — fix: add a scenario where the task changes its suite file after `base_sha` and the label depends on it.
[Suggestion] [tests] tests/verify-tests/verify-tests.test.sh:41-42 — "args: no arguments is usage" checks only `$rc:$out`; passes even if no usage printed — include stderr or drop.
[Suggestion] [tests] tests/verify-tests/verify-tests.test.sh:290-291 — "second signal during cleanup" signals 0.2 s apart; passes with or without the cleanup trap — make cleanup slow enough, or document.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh:981-990 — the `plan-state tests` exit-2 order between steps 4/5 and 5/6 is untested — add a plan with both faults per pair.
[Suggestion] [correctness] skills/writing-dag-plans/plan-state:51 — a `tests:` block with unindented entries is silently ignored, so verify-tests passes with "no named tests" — flag it as rule 16.
[Suggestion] [correctness] skills/executing-dag-plans/verify-tests:48 — when job control is off, the fallback signals only the subshell; the suite's processes survive — signal descendants or document.
[Suggestion] [clarity] skills/executing-dag-plans/SKILL.md:59-60 — flow diagrams list exit 1 before 0 and leave out exit 2 — list 0, 1, 2 (and at 70-71).
[Suggestion] [clarity] skills/executing-dag-plans/SKILL.md:84 — "On every ISSUES verdict" — add "or verify-tests exit 1".
[Suggestion] [clarity] skills/executing-dag-plans/SKILL.md:90 — "`set` rewrites only the status line" no longer true.
[Suggestion] [clarity] commands/audit-plan.md:19 — "S1–S16" — S1–S17.
[Suggestion] [clarity] skills/auditing-artifacts/SKILL.md:223 — "S1–S16" — S1–S17.
[Suggestion] [spec] skills/writing-dag-plans/plan-format.md:128 — says "a leading `./` removed"; spec and code remove every leading `./`.
[Suggestion] [clarity] skills/writing-dag-plans/plan-format.md:132 — "The after tree is the task's committed head" is wrong; it is the repository's HEAD at check time.

TOTAL: 2 Important, 12 Suggestion
