Review of 8707b69 against c57de12, compared with docs/superpowers/specs/2026-11-17-named-tests-design.md and CLAUDE.md.

Tests: both suites pass under Git Bash with gawk. verify-tests: 40 passed, 0 failed. plan-state: 252 passed, 0 failed. mawk and busybox awk not installed, so the awk portability rule was not checked by running. A by-hand case (a file deleted after base_sha is restored in the before tree) labels `ok`, which is correct.

[Important] [spec] skills/executing-dag-plans/merged-reviewer-prompt.md:56 — The "Red-to-green evidence" section was left unchanged: it still requires RED-THEN-GREEN evidence and calls missing evidence ISSUES. The spec says for a criterion with a verified named test the reviewer must "not re-run or re-derive it"; implementer-prompt.md lets the implementer leave it out, so a task whose criteria are all named tests can get a spurious ISSUES — limit the section to criteria without a named test.
[Important] [correctness] skills/executing-dag-plans/quality-reviewer-prompt.md:68 — The quality reviewer gets no verify-tests output, but its "Red-to-green evidence" rule still calls missing evidence ISSUES; a fully named-test task can be bounced in the split flow and burn fix rounds — give it the output, or exempt named-test criteria, and record the exception to the spec's "Quality reviewer: no change".
[Suggestion] [clarity] skills/executing-dag-plans/implementer-prompt.md:83 — RED-THEN-GREEN bullet contradicts the Named tests section (line 74).
[Suggestion] [clarity] skills/executing-dag-plans/SKILL.md:84 — "On every ISSUES verdict" — add "or verify-tests exit 1".
[Suggestion] [clarity] skills/writing-dag-plans/plan-format.md:112 — `review_rounds` comment omits failed verify-tests.
[Suggestion] [clarity] skills/writing-dag-plans/plan-format.md:258 — `failed` row omits reaching the cap through verify-tests.
[Suggestion] [clarity] commands/audit-plan.md:19 — "S1–S16" — S1–S17.
[Suggestion] [clarity] skills/auditing-artifacts/SKILL.md:223 — "S1–S16" — S1–S17.
[Suggestion] [correctness] skills/executing-dag-plans/SKILL.md:87 — a Bash tool timeout sends no signal (verify-tests:15-20); the controller is not told what to do when the call is moved to background — say: wait for completion, or halt as exit 2.
[Suggestion] [correctness] skills/executing-dag-plans/verify-tests:45 — `kill "$child"` signals only `sh -c`; a compound test_command can leave the suite orphaned — use a process group, or document.
[Suggestion] [correctness] skills/executing-dag-plans/verify-tests:94 — `rm -rf "$before/$p"` on a raw `files:` path; `..` deletes outside — refuse such paths.
[Suggestion] [tests] tests/verify-tests/verify-tests.test.sh:289 — "tails: file order follows tests:" uses a `files:` order matching `tests:` order — reverse it.
[Suggestion] [tests] tests/verify-tests/verify-tests.test.sh:136 — only one `ambiguous` case (two pass lines in both trees) — add before-only, and pass-plus-fail.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh:877 — "When the task already has a base_sha:, git is not called" untested — add a no-repo case.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh:981 — `rc=$?` is sed's exit code after a pipe, so the `0:` part cannot fail (also line 948) — capture first.
[Suggestion] [tests] tests/verify-tests/verify-tests.test.sh:55 — tree, label and tail cases run only under `sh` (bash), not dash — repeat T4 under "$ALTSH".
TOTAL: 2 Important, 14 Suggestion
