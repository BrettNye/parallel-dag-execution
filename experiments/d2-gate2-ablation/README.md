# D2 experiment tools

Tools for `docs/superpowers/specs/2026-11-16-d2-gate2-ablation-design.md` in
parallel-dag-execution. They live outside the repository until the report is written, so no
run can read them, and they move to `experiments/d2-gate2-ablation/` with the report. The
hidden functional suite lives in `scratch/d2-hidden/` until then, for the same reason.

| File | What it does |
|---|---|
| `pin-plugin.sh <repo> <commit> <dest-parent>` | Plain export of the plugin at one commit, loaded by every run with `--plugin-dir`. |
| `snapshot.sh <gate2-worktree> <plan> <S0\|S1\|S2>` | Tags the committed plan `d2-<S>` after `plan-state check` passes. A tag never moves. |
| `make-run.sh <repo> <base> <arm> <n> <plan> <dest-parent>` | One run's worktree, `pde-d2-run-<id>` on `d2/run-<id>`: base plus the arm's snapshot, `experiments/` left out, the arm kept only in `runs/run-map.txt`. |
| `run-arm.sh <label> <worktree> <plugin-dir> <plan> <budget-usd>` | One headless executor invocation. Prints the session id. |
| `run-audit.sh <label> <worktree> <plugin-dir> <plan> <round>` | One gate-2 round. Round 1 uses all eight lenses; later rounds use the skill's diff-scoped re-audit. |
| `run-fix.sh <label> <worktree> <plan> <prompt-file>` | One fix session from `fix-prompt.md` or `preflight-fix-prompt.md`. |
| `hidden-check.sh <worktree> [<suite-dir>]` | Every branch suite, then the hidden suite, under mawk, gawk and busybox in Docker. |
| `make-blind.sh <repo> <dest-parent> <branch>...` | Shuffled letters P to U, detached review worktrees, and `runs/blind-key.txt`. |
| `measure.cjs <manifest.json> [--json]` | Shared gate-2 stages, per-run and per-arm cost, interventions with infra stops kept apart, and the none/full and round1/full ratios. |
| `functional-suite-prompt.md`, `trace-prompt.md`, `blind-review-prompt.md` | Dispatched by hand to fresh Opus 5.5 subagents. |
| `keepawake.ps1 [-Hours N]` | Holds the PC awake. Create `keepawake.stop` beside it to end early. |

All the `run-*` scripts set `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`, and they write logs to
`runs/` (or `$D2_RUNS`). Tests: `bash test/runners.test.sh`, `bash test/snapshot.test.sh`,
`bash test/blind.test.sh`, `node test/measure.test.cjs`. `hidden-check.sh` is checked on
`test/hidden-fixture/`.

## Procedure

Record every session id in `manifest.json` as you go: shared stages under `shared`
(`plan-writing`, `gate2-r1`, `fix-r1`, `gate2-r2`, `fix-r2`, ..., adding each later round), run
sessions under `runs.<run>.stages`.

1. **E3 first.** Brainstorm E3 and write its spec, pinning the command interface exactly. Pass
   gate 1 and commit the spec. That commit is `<base>`.
2. **Hidden suite.** Dispatch `functional-suite-prompt.md` with the spec, writing into
   `scratch/d2-hidden/`. Run `hidden-check.sh <repo at base> scratch/d2-hidden` once. Every
   hidden case should fail at base. Examine any that passes, and drop it if it tests nothing
   new. Record the number of cases per suite file in `manifest.json` notes. When scoring, a
   case that did not run because its suite aborted counts as failed.
3. **Freeze the setup.** Make `C:/Users/Brett/d2-runs/`, outside the workspace, so no run sits beside
   `scratch/d2-hidden` or these tools. Run `pin-plugin.sh <repo> <base> C:/Users/Brett/d2-runs`. Raise
   Claude Code's `cleanupPeriodDays`. Start `powershell -File keepawake.ps1 -Hours 12` in the
   background, and restart it as needed.
4. **Gate-2 worktree.** `git worktree add --no-checkout -b d2/gate2 <dir> <base>`, then,
   inside it, `MSYS_NO_PATHCONV=1 git sparse-checkout set --no-cone '/*' '!/experiments/'`
   and `git checkout`.
5. **S0.** Write the plan there with `writing-dag-plans`, in the normal format. Commit it and
   run `snapshot.sh <dir> <plan> S0`. If the plan has fewer than 12 tasks, stop and tell
   Brett.
6. **S1.** Run `run-audit.sh gate2-r1 <dir> <plugin> <plan> 1` (it keeps the round's
   `.audit/` files as `runs/audit-gate2-r1/`, since the next round overwrites them), then
   `run-fix.sh fix-r1 <dir> <plan> fix-prompt.md`. Commit, and run `snapshot.sh ... S1`.
   - If round 1 was READY, also tag the same commit as S2 and run the full arm only.
7. **S2.** For N = 2, 3, ...: run `run-audit.sh gate2-rN ... N` and
   `run-fix.sh fix-rN ... fix-prompt.md`, and commit. Stop at READY, or at the skill's
   convergence stop. Commit, and run `snapshot.sh ... S2`.
8. **Budget.** Set it to twice the full arm's planned execution cost: D1's arm A execution was
   $13.25 for 10 tasks, so scale that by the S2 task count. Write the figure into
   `manifest.json` notes before the first run.
9. **Six runs, in this order:** none-1, round1-1, full-1, none-2, round1-2, full-2. For each,
   run `make-run.sh <repo> <base> <arm> <n> <plan> C:/Users/Brett/d2-runs`. It prints the worktree,
   `C:/Users/Brett/d2-runs/pde-d2-run-<id>` on branch `d2/run-<id>`, and records `<arm>-<n> <id> ...` in
   `runs/run-map.txt`; nothing the run can see names its arm. Then run
   `run-arm.sh <arm>-<n> <worktree> <plugin> <plan> <budget>`. Re-invoke the same way until
   the plan is terminal. `run-arm.sh` passes each re-invocation only what is left of the
   run's budget, and exits 3 once it is spent.
   - **Preflight halt:** save the printed output to
     `docs/superpowers/plans/.preflight-output.txt` in the run's worktree. Run
     `run-fix.sh <arm>-<n>-pf <worktree> <plan> preflight-fix-prompt.md`. Delete the output
     file, commit the plan, record the session under `preflight-fix`, and re-invoke.
   - **Infra stop** (auth error, crash, sleep): record the stopped session under `infra` and
     re-invoke. After a run's third infra stop, delete its branch and worktree and redo it
     from `make-run.sh`.
   - **Budget cap hit** (`run-arm.sh` exits 3, or the CLI stops on the budget): the run did
     not finish. It still goes through steps 10 and 11.
   - **Redone run:** before `make-run.sh` again, delete the old branch and worktree, remove
     its line from `runs/run-map.txt`, empty its manifest entry, and add a note listing the
     discarded sessions.
10. **Hidden check.** Run `hidden-check.sh <worktree> scratch/d2-hidden` on all six. Save
    each output to `runs/hidden-<arm>-<n>.txt`. An exit of 2 (`incomplete`) means a container
    failed to set up: rerun it.
11. **Blind review.** Run `make-blind.sh <repo> C:/Users/Brett/d2-runs <the six d2/run-<id> branches>`.
    Then do six reviews with `blind-review-prompt.md`, one per `review-<L>`, saved to
    `runs/blind-<L>.md`.
12. **Trace.** Copy each run's evidence into `runs/trace/<L>/` by letter, as
    `trace-prompt.md` says, and dispatch it with those paths only. Brett spot-checks at least
    three rows.
13. **Broken hidden cases.** Before scoring, examine any hidden case that fails on all six
    branches, including both full runs. If the suite is wrong, drop the case and say so in the
    report.
14. **Score.** Run `node measure.cjs manifest.json` and run `audit-stats runs/audit-gate2-r*`
    over the kept rounds. `measure.cjs` warns about any run with no execution sessions and
    leaves it out of its arm's mean. Apply the design's decision rule, write `REPORT.md`, and move this
    directory and `scratch/d2-hidden` into `experiments/d2-gate2-ablation/`.
15. **Merge.** Take the better full run (hidden suite first, then fewer Important findings,
    then lower cost). Fix its Important findings, merge, and delete the other branches,
    worktrees and tags.
