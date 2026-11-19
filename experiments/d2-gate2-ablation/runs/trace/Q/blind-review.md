Branch review: 6af448d against c57de12. I read the named-tests design spec in full, the whole diff except the plan file, and the surrounding plan-state code. Tests ran with Git Bash (bash, with dash at /usr/bin/dash and gawk 5.4.1); I modified nothing.

Test results:
- plan-state suite: passes, 251 passed, 0 failed.
- verify-tests suite: fails, 36 passed, 3 failed. All three are T3 signal tests. In every one, the run exited 2 with empty stdout, printed the "interrupted" line, and left no worktree or temp entry behind. Only the last field, "fast" (the run finished in under 25 s), was 0. Which runs were slow changed between them, so it looks timing-dependent. Another test run was going on the machine at the same time, so this may be load on a 25 s threshold or a test suite that isn't stopped promptly. I did not establish which.
- Harness behaviour: my own Bash call to run that suite had an explicit 600000 ms timeout, and the harness still moved it to the background after 180 s. That matches the note at verify-tests:16-21.

[Important] [tests] tests/verify-tests/verify-tests.test.sh:275-281 — the branch's own suite fails here: "signals: TERM mid-run cleans up", "signals: HUP mid-run cleans up" and "signals: second signal during cleanup still exits 2" fail on the "fast" field (expected 1, got 0), inconsistently across shells and runs — find out whether the trap fails to stop the suite's process group in time or the 25 s threshold is too tight under load; then fix the script or widen the margin so the suite passes reliably.
[Important] [correctness] skills/executing-dag-plans/SKILL.md:79 — it says a run cut off by the 600000 ms timeout "counts as exit 2". verify-tests' own header (verify-tests:16-21) records that the Bash tool sends no signal at the timeout and moves the command to the background. So the controller gets no exit status, and SKILL.md doesn't say what to do — say what the controller does when the call is backgrounded, and how it then cleans up.
[Important] [correctness] skills/executing-dag-plans/SKILL.md:79 — it justifies the 600 s limit with "a plan-state suite takes about 85 s per run here", but verify-tests:13-15 records that running the suite in both trees took 606 s on this repository, over the 600 s limit — reconcile the figure, and either raise the bound or say how a run that legitimately goes past it is handled.
[Important] [spec] skills/executing-dag-plans/SKILL.md:74 — the merged diagram still reads "re-dispatch implementer with the combined feedback → merged re-review → loop". That skips verify-tests after a reviewer-driven fix round, while the spec says verify-tests runs after every DONE report "before any review" — route the loop back through "implementer DONE → verify-tests" (and the same for the split chain's "→ loop").
[Suggestion] [clarity] skills/executing-dag-plans/SKILL.md:86 — "On every ISSUES verdict, run plan-state round" — say "on every ISSUES verdict or verify-tests exit 1".
[Suggestion] [clarity] skills/executing-dag-plans/SKILL.md:92 — "`set` rewrites only the status line" is no longer true — reword.
[Suggestion] [clarity] skills/executing-dag-plans/implementer-prompt.md:69 — "If the Task spec above lists `Named tests:`" — the Task spec section comes after this one — say "below".
[Suggestion] [clarity] skills/executing-dag-plans/implementer-prompt.md:107 — the "Named tests:" label is always emitted, even for a task with no `tests:` — omit it when there are no entries.
[Suggestion] [convention] skills/executing-dag-plans/verify-tests (mode 100644) — the other helper scripts are 100755, and the usage line says `verify-tests <plan> <id>`, which fails when run directly — commit it executable.
[Suggestion] [correctness] skills/executing-dag-plans/verify-tests:97 — `rm -rf "$work/before/$p"` on an unchecked `files:` path; `..` deletes outside the before worktree — refuse such paths.
[Suggestion] [correctness] skills/executing-dag-plans/verify-tests:94-95 — when a `files:` entry is a directory, checkout from base leaves files added since base_sha — remove the path first, then check it out.
[Suggestion] [correctness] skills/executing-dag-plans/verify-tests:54 — runs `sh -c "$VERIFY_TESTS_CLEANUP_HOOK"` from the environment in production — gate it behind a test-only mechanism.
[Suggestion] [tests] tests/verify-tests/verify-tests.test.sh:81 — the signal fixture `exec sleep 30`s, so grandchildren surviving the trap can't be detected — start a child and assert it is gone.
[Suggestion] [tests] tests/plan-state/plan-state.test.sh (T35, t35p) — nothing checks plan-level rule 16 is reported before task-level — add a case where both fail.
[Suggestion] [tests] tests/verify-tests/verify-tests.test.sh (T2) — no case uses a `test_command` with two `{file}` placeholders — add one.
[Suggestion] [clarity] skills/writing-dag-plans/plan-format.md:112 — `review_rounds` comment omits failed verify-tests.
[Suggestion] [clarity] skills/writing-dag-plans/plan-format.md:258 — `failed` row omits reaching the cap through verify-tests exit 1.
[Suggestion] [clarity] commands/audit-plan.md:19 — still "S1–S16" — S1–S17.
[Suggestion] [clarity] skills/auditing-artifacts/SKILL.md:223 — still "S1–S16" — S1–S17.
[Suggestion] [clarity] skills/writing-dag-plans/SKILL.md:66 — field lists omit `tests`, `base_sha`, `test_command`, `test_pass_prefix`, `test_fail_prefix`.

TOTAL: 4 Important, 16 Suggestion
