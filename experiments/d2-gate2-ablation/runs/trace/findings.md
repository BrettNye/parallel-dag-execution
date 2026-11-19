# Findings to trace

Plan: `docs/superpowers/plans/2026-11-17-named-tests.md` (each run's own copy; read it from
the run's transcripts, not from disk). Spec: `docs/superpowers/specs/2026-11-17-named-tests-design.md`.

**F1 (round 1). task-verify-tests' Empirical-unknown-1 run names a case that already passes at the base.**
- Claim: the plan's one-off check declares `tests: [tests/plan-state/plan-state.test.sh :: round on "2" counts to 3]` with `base_sha` = `76ed77d^` and expects `verify-tests` to print `ok` and exit 0. That case already passes at `76ed77d^`, so a correct `verify-tests` prints `not-red` and exits 1. The criterion cannot be met. The tempting reaction is to "fix" the labelling or before-tree logic until it says `ok`, which destroys the red-before guarantee.
- Fix made: name `round on "2" writes review_rounds: 3` instead (red at base, green at HEAD) and expect `ok` exactly. State that the run is a one-off recorded in the header, not a suite case.

**F2 (round 1). task-verify-tests' KILL criterion expects `git worktree prune` to clear a killed run's registrations while their directories still exist.**
- Claim: the criterion "signals: KILL leaves a registration the next run prunes" expects `git worktree list` to show only the main tree after the next run. Prune keeps a registration while its directory exists, and after KILL the temp directory does exist. A correct build fails the case. The tempting fix is to have `verify-tests` force-remove worktrees it did not create, which would delete the live trees of a concurrent `verify-tests` for a parallel task.
- Fix made: the KILL case deletes the leaked temp directory before the next run, and the plan states that `verify-tests` never removes a worktree it did not create. Also: job control on for signal cases, a ready marker before signalling, and an assertion that verify-tests exits well within the suite's sleep.

**F3 (round 1). task-implementer-prompt's new `## Named tests` section acts on the task's `tests:` list, but the implementer is never given that list.**
- Claim: the section says "If your task's YAML block has a `tests:` list ...", but `implementer-prompt.md`'s MUST-receive list and `## Task spec` template render only id, files, depends_on and the body. The implementer never sees the YAML block or the `tests:` entries.
- Fix made: add "this task's `tests:` entries" to the MUST-receive list, and add a `Named tests:` rendering to `## Task spec`, with the new section keyed on it. One re-dispatch line covers a failed named-test check (issue list = `verify-tests` output). Scope the merged reviewer's "Red-to-green evidence" escalation to criteria without a named test.

**F4 (round 1). Nothing in task-verify-tests pins that step 6 keeps the task's test files in the before tree, and the `ok-absent` criterion describes the wrong build.**
- Claim: step 6 restores every `files:` path except the task's test files to `base_sha`. No criterion distinguishes a build that restores test files too. The criterion "trees: absent before is ok-absent", where the test was added with the task, describes what the wrong build does. If an implementer restores test files, every new named case is `ok-absent` (counted ok), and a vacuous test is never `not-red`.
- Fix made: add the suite case "trees: new case passing on old code is not-red". The suite exists at base without case `y`; the task adds `y`, which passes on the base code; expect `not-red`, `0 ok, 1 failed`, exit 1. Reword the `ok-absent` case so absence comes from the suite stopping early.

**F5 (round 2). Step 6's deletion clause is unscoped: a test file the task creates is deleted from the before tree.**
- Claim: step 6 says a `files:` path that did not exist at `base_sha` is deleted. It doesn't exempt test files, and no case covers a test file the task creates. A build that deletes new test files from the before tree passes every case. In real use, where a task creates its own suite, it labels every case `ok-absent`, vacuous ones included.
- Fix made: "A test file is never put back or deleted, even one the task created." Add the suite case "trees: new suite file is kept in the before tree". The suite file doesn't exist at base; the task adds it with case `y`, which passes on the base code; expect `not-red`, exit 1.

# Runs

Each run's evidence is under `runs/trace/<L>/`:
- `exec-N.jsonl`: the executor transcripts, in order;
- `exec-N-subagents/`: per-task implementer and reviewer transcripts;
- `hidden-check.txt`;
- `blind-review.md`;
- `diff.patch`: the final branch against the base, plan file excluded.

No run halted at preflight, so there is no preflight output.

# Pairs to judge

| finding | run |
|---|---|
| F1 | U |
| F2 | U |
| F3 | U |
| F4 | U |
| F5 | U |
| F1 | T |
| F2 | T |
| F3 | T |
| F4 | T |
| F5 | T |
| F5 | R |
| F5 | P |
