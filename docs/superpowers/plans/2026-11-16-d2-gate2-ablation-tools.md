# D2 Gate-2 Ablation Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the tools the D2 experiment runs with: snapshots, run worktrees, headless
runners, the hidden check with a functional suite, measurement, blind-review setup, and the
procedure. The plan builds tools only. Running the experiment follows the procedure in Task 8,
and that procedure starts with E3's own spec.

**Architecture:** D1's tools are copied from `experiments/d1-no-implementation/` into a tools
directory outside the repository, and adapted there. The changes:
- three arms built from git-tagged plan snapshots, not separate plans;
- one shared gate-2 run;
- infra stops logged apart from interventions;
- a hidden functional suite, run after each branch's own suites;
- six blind-review worktrees.

The tools move into `experiments/d2-gate2-ablation/` with the report, as D1's did.

**Tech Stack:** bash (Git Bash on Windows), git worktrees and tags, Docker (Debian and Alpine
images), Node 22 (`measure.cjs`), `claude -p`.

**Spec:** `docs/superpowers/specs/2026-11-16-d2-gate2-ablation-design.md`

## Global Constraints

- **Tools directory.** `TOOLS = C:/Users/Brett/workspace/scratch/d2-tools/`. It is outside the
  repository until the report is written: anything committed before the base commit would be
  in every run's worktree.
- **The hidden functional suite** lives at `C:/Users/Brett/workspace/scratch/d2-hidden/`, also
  outside the repository. No tool prints its path into a prompt.
- **Every run's worktree leaves `experiments/` out of its checkout** (git sparse-checkout).
  D1's hidden check and blind-review prompt live there.
- **Every headless run** uses `--model opus`, `--permission-mode auto` and
  `--permission-prompts none`, and the environment variable
  `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`.
- **Gate-2 round 1** runs the full plan lens set. Rounds 2 and later run the diff-scoped
  re-audit the `auditing-artifacts` skill describes, with no lens instruction added.
- **`measure.cjs` never prints message content.**
- **Snapshot tags** are `d2-S0`, `d2-S1` and `d2-S2`. Run branches are `d2/<arm>-<n>`, with
  `<arm>` one of `none`, `round1` or `full`, and `<n>` either 1 or 2.
- **Commit identity** in the repository: `Brett Nye <43053436+BrettNye@users.noreply.github.com>`.

## Review Focus

1. **A path with a space** (worktree, plugin or plan): every script quotes it. Tested in Tasks 2
   and 3.
2. **A snapshot tag or run branch that already exists:** refuse with exit 2, and never move a
   tag. Tested in Task 3.
3. **A snapshot whose plan fails `plan-state check`:** refuse to tag it. Tested in Task 3.
4. **A manifest naming a session whose transcript is missing:** `measure.cjs` names the
   missing id and exits 2, and doesn't report a run as cheap. Tested in Task 5.
5. **More infra stops listed than re-invocations:** the plan-caused count floors at 0. Tested in
   Task 5.

---

### Task 1: Tools directory and the headless runners

**Files:**
- Create: `TOOLS/run-arm.sh`, `TOOLS/run-audit.sh`, `TOOLS/run-fix.sh`, `TOOLS/pin-plugin.sh`,
  `TOOLS/fix-prompt.md`, `TOOLS/blind-review-prompt.md`, `TOOLS/keepawake.ps1`
- Test: `TOOLS/test/runners.test.sh`

**Interfaces:**
- Produces:
  - `run-arm.sh <label> <worktree> <plugin-dir> <plan> <budget-usd>`
  - `run-audit.sh <label> <worktree> <plugin-dir> <plan> <round>`, where `<round>` is a
    positive integer
  - `run-fix.sh <label> <worktree> <plan> <prompt-file>`
  - Each prints `session <id> ...` and writes `TOOLS/runs/<kind>-<label>-<utc>.json`.
  - `pin-plugin.sh` and `keepawake.ps1` are unchanged from D1. `keepawake.ps1` is taken from
    the session scratchpad copy shown in the D1 run: `-Hours`, plus a `keepawake.stop` file
    beside it to end early.

- [ ] **Step 1: Copy the D1 files.** Copy `pin-plugin.sh`, `run-arm.sh`, `run-audit.sh`,
  `run-fix.sh`, `fix-prompt.md` and `blind-review-prompt.md` from
  `experiments/d1-no-implementation/` into `TOOLS/`. Add `keepawake.ps1`.
- [ ] **Step 2: Write the failing test.** `test/runners.test.sh` puts a fake `claude` first on
  `PATH`. The fake writes its argv, one argument per line, to `$FAKE_OUT/argv` and
  `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` to `$FAKE_OUT/env`, then prints
  `{"session_id":"s1","subtype":"success","total_cost_usd":0,"num_turns":1,"result":"ok"}`.
  It asserts:
  - `run-arm.sh` with a worktree path containing a space: exit 0, `env` holds `0`, and argv
    holds `--max-budget-usd` followed by the budget;
  - `run-audit.sh ... 1`: the prompt contains `all eight lenses`;
  - `run-audit.sh ... 2`: the prompt contains `diff-scoped re-audit` and does not contain
    `all eight`;
  - `run-audit.sh ... 0` and `run-audit.sh ... x`: exit 2;
  - `run-fix.sh` with a prompt file whose text is `fix {plan} {planname}`: the prompt is
    `fix docs/p.md p.md`;
  - each script with the wrong number of arguments: exit 2;
  - a missing plan: exit 2.
- [ ] **Step 3: Run it and see it fail.** `bash test/runners.test.sh`. Expected: FAIL on the
  `env`, round and prompt-file cases.
- [ ] **Step 4: Change the runners.**
  - `run-arm.sh` and `run-audit.sh` export `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`.
  - `run-audit.sh` takes `<round>`:
    - round 1 keeps D1's prompt, which uses the full lens set;
    - later rounds replace the lens sentence with: `This is round <round>. Run the diff-scoped
      re-audit the skill describes: only the lenses the change since the last audit touches,
      recording the others as carried.`
  - `run-fix.sh` replaces its `<full|contracts-only>` argument with `<prompt-file>`, and keeps
    only the `{plan}` and `{planname}` substitutions. Delete the contracts-only rule.
- [ ] **Step 5: Run the test and see it pass.** `bash test/runners.test.sh`. Expected:
  `RESULT: N passed, 0 failed`.
- [ ] **Step 6: No commit.** `TOOLS` is outside the repository. Record "Task 1 done" in
  `TOOLS/BUILD-LOG.md`, with the test's RESULT line.

### Task 2: Hidden check with the functional suite

**Files:**
- Create: `TOOLS/hidden-check.sh`, by copying D1's and changing it
- Test: `TOOLS/test/hidden-fixture/` (a tiny repo export and a tiny suite), checked by running
  the script for real

**Interfaces:**
- Produces: `hidden-check.sh <worktree> [<suite-dir>]`.
  - Without `<suite-dir>` it behaves exactly as D1's.
  - With it, it mounts `<suite-dir>` read-only at `/hidden`. After the branch's own suites, it
    runs each `/hidden/*.test.sh` with the working copy as the current directory and prints
    `PASS <awk> hidden/<file>` or `FAIL <awk> hidden/<file>`, using D1's pass rule. It also
    prints, from the suite's output, each line matching `^  (PASS|FAIL): `, prefixed with
    `<awk> hidden/<file>`, so the report can count cases.
  - Totals: `HIDDEN CHECK: <p> passed, <f> failed` over suites, then
    `HIDDEN CASES: <p> passed, <f> failed` when a suite dir was given.

- [ ] **Step 1: Build a fixture.** `test/hidden-fixture/repo/` holds a git-free tree with
  `tests/ok/ok.test.sh`, which prints `RESULT: 1 passed, 0 failed` and exits 0.
  `test/hidden-fixture/suite/` holds `a.test.sh`, which prints `  PASS: one` and `  FAIL: two`
  and exits 1.
- [ ] **Step 2: Implement the suite mount.** Add `-v "<suite>:/hidden:ro"` to both
  `docker run` calls when a suite dir is given. Convert it with `cygpath -w` as D1 does for
  `src`. In `run_suites`, add the loop over `/hidden/*.test.sh`.
  - The fixture repo is not a git work tree, so the script needs a way to take a plain
    directory: export from git when `<worktree>/.git` exists, otherwise copy the directory.
- [ ] **Step 3: Run it on the fixture.**
  `bash hidden-check.sh test/hidden-fixture/repo test/hidden-fixture/suite`. Expected:
  - three `PASS <awk> tests/ok/ok.test.sh` lines;
  - three `FAIL <awk> hidden/a.test.sh` lines;
  - `HIDDEN CHECK: 3 passed, 3 failed`;
  - `HIDDEN CASES: 3 passed, 3 failed`;
  - exit 1.
- [ ] **Step 4: Run it on the repo without a suite.**
  `bash hidden-check.sh <repo root>`. Expected: `HIDDEN CHECK: 15 passed, 0 failed`, which is
  today's 5 suites under 3 awks.
- [ ] **Step 5: Log it.** Append both RESULT lines to `TOOLS/BUILD-LOG.md`.

### Task 3: Snapshots and run worktrees

**Files:**
- Create: `TOOLS/snapshot.sh`, `TOOLS/make-run.sh`
- Test: `TOOLS/test/snapshot.test.sh`

**Interfaces:**
- Consumes: `skills/writing-dag-plans/plan-state check` in the repository.
- Produces:
  - **`snapshot.sh <gate2-worktree> <plan> <S0|S1|S2>`**
    - Refuses with exit 2 when `plan-state check <plan>` prints anything, when the plan has
      uncommitted changes, or when tag `d2-<S>` exists.
    - Otherwise it tags HEAD `d2-<S>`, prints the tag and the commit, and exits 0.
  - **`make-run.sh <repo> <base> <arm> <n> <plan> <dest-parent>`**
    - `<arm>` must be `none`, `round1` or `full`, and `<n>` must be 1 or 2.
    - The arm maps to tags: none → `d2-S0`, round1 → `d2-S1`, full → `d2-S2`.
    - Refuses with exit 2 when the branch `d2/<arm>-<n>` or the directory
      `<dest-parent>/pde-d2-<arm>-<n>` exists.
    - Otherwise it:
      1. adds a worktree at `<dest-parent>/pde-d2-<arm>-<n>` on a new branch `d2/<arm>-<n>`
         from `<base>`;
      2. sets sparse-checkout to everything except `experiments/`
         (`git sparse-checkout set --no-cone '/*' '!/experiments/'`);
      3. writes the plan from `git show d2-<S>:<plan>`;
      4. commits it as `docs(plans): <arm> arm, snapshot <S>`;
      5. prints the worktree path.

- [ ] **Step 1: Write the failing test.** It works in a temp git repo that has
  `skills/writing-dag-plans/plan-state` copied from the real repo, a minimal valid plan, and an
  `experiments/x.txt`. It asserts:
  - `snapshot.sh` tags `d2-S0`;
  - a second `snapshot.sh ... S0` exits 2 and leaves the tag on the same commit;
  - a plan with a duplicate id makes `snapshot.sh ... S1` exit 2, and no tag is created;
  - `make-run.sh` produces a worktree whose plan equals `git show d2-S0:<plan>`, and whose
    directory has no `experiments/`;
  - running `make-run.sh` again with the same arm and n exits 2;
  - arm `best` exits 2, and n `3` exits 2;
  - a `<dest-parent>` containing a space works.
- [ ] **Step 2: Run it and see it fail.** `bash test/snapshot.test.sh`. Expected: FAIL, because
  the scripts don't exist.
- [ ] **Step 3: Implement both scripts.** Both use `set -eu`, and both print their usage from
  the header comment on an argument error, with exit 2, as D1's scripts do.
- [ ] **Step 4: Run the test and see it pass.** Expected: `RESULT: N passed, 0 failed`.
- [ ] **Step 5: Log it.** Append the RESULT line to `TOOLS/BUILD-LOG.md`.

### Task 4: Prompts for the functional suite, the preflight fix and the finding trace

**Files:**
- Create: `TOOLS/functional-suite-prompt.md`, `TOOLS/preflight-fix-prompt.md`,
  `TOOLS/trace-prompt.md`

**Interfaces:**
- Produces: three prompt files.
  - `run-fix.sh` reads `preflight-fix-prompt.md` (placeholders `{plan}` and `{planname}`).
  - The other two are dispatched by hand, as fresh `general-purpose` subagents on Opus 5.5.

- [ ] **Step 1: `functional-suite-prompt.md`.**
  - The writer gets the E3 spec path and nothing else: no plan, no branch. It writes bash
    suites into a directory it is given, in the repository's suite style: `ok`, `bad`, `chk`,
    and a final `RESULT: N passed, M failed`.
  - The suites test only behaviour the spec pins down: commands, arguments, exit codes,
    output. They must run from the root of a working copy.
  - Each case names the spec line it tests.
  - Where the spec leaves a behaviour open, the writer lists it under "not tested: spec leaves
    open" and does not guess.
- [ ] **Step 2: `preflight-fix-prompt.md`.**
  - The fixer gets the plan and the printed preflight output, saved to
    `docs/superpowers/plans/.preflight-output.txt` by whoever runs it. It fixes only the
    errors printed there.
  - It may change only `files:` lists and the cited paths in task text.
  - Then it runs `plan-state check` and `plan-state preflight`. Preflight must exit 0.
  - It does not commit. It reports each error and the change made for it.
- [ ] **Step 3: `trace-prompt.md`.**
  - The tracer gets: the list of blocking findings gate 2 fixed (from the reconciliation files
    for S0 to S2), and, for each run, a letter label, its branch, its execution transcripts'
    paths and its hidden-check output. It never gets arm names.
  - For each pair of a finding and a run whose plan lacked the fix, it assigns exactly one of:
    `caught-by-preflight`, `caught-by-review`, `broke-run`, `shipped`, `didnt-matter`. Each
    comes with one line of evidence: a file and line, or a transcript quote of at most 20 words.
  - The tracer is told which runs lacked which fix by the runner, from the snapshot each run
    used, not by arm name.
  - Output: a table with one row per pair.
- [ ] **Step 4: Review.** Read each prompt against the design's rules: who sees what, the five
  trace outcomes, and the fix limited to preflight output. Note the check in
  `TOOLS/BUILD-LOG.md`.

### Task 5: `measure.cjs` for one shared gate 2 and per-run executions

**Files:**
- Create: `TOOLS/measure.cjs`, copied from D1 and changed
- Test: `TOOLS/test/measure.test.cjs`, copied from D1 and extended

**Interfaces:**
- Produces: `node measure.cjs <manifest.json> [--json]`. The manifest:

```json
{
  "projectsDir": "C:/Users/Brett/.claude/projects",
  "shared": { "plan-writing": ["<id>"], "gate2-r1": ["<id>"], "fix-r1": ["<id>"],
              "gate2-r2": ["<id>"], "fix-r2": ["<id>"] },
  "arms": { "none": { "snapshot": "d2-S0", "plan": "<path>" },
            "round1": { "snapshot": "d2-S1", "plan": "<path>" },
            "full": { "snapshot": "d2-S2", "plan": "<path>" } },
  "runs": { "none-1": { "arm": "none", "stages": { "execution": ["<id>"], "preflight-fix": ["<id>"] },
                        "infra": ["<id of an execution session that ended on an infra stop>"] } }
}
```

- **Charging the shared stages:**
  - none: `plan-writing`;
  - round1: `plan-writing`, `gate2-r1`, `fix-r1`;
  - full: every shared stage.
- **Per run:**
  - execution = `execution` + `preflight-fix`;
  - plan-caused interventions = max(0, execution sessions − 1 − infra count)
    \+ extra prompts + NEEDS_CONTEXT + `preflight-fix` sessions.
- **Per arm:** the shared charge, plus the mean of its runs' execution. Interventions are the
  sum over its runs.
- **Output:**
  - a table per run;
  - a table per arm, with tokens, $, active time and interventions;
  - the lines `none / full: $ <r>, tokens <r>, active <r>` and
    `round1 / full: $ <r>, tokens <r>, active <r>`.
- A session id with no transcript: print `measure: no transcript for <id>` and exit 2.

- [ ] **Step 1: Write the failing tests.** Extend `test/measure.test.cjs` with a D2 fixture:
  - shared stages of $1, $2, $1, $2 and $1 (plan-writing, gate2-r1, fix-r1, gate2-r2, fix-r2);
  - none-1 at $3, with a `preflight-fix` session at $1;
  - none-2 at $5;
  - round1 runs at $4 and $4;
  - full runs at $3 and $3;
  - none-2 has two execution sessions and lists the first in `infra`.

  Assert:
  - arm $: none = 1 + mean(3 + 1, 5) = 5.5; round1 = 1 + 2 + 1 + 4 = 8; full = 7 + 3 = 10;
  - none's interventions = 1 (the preflight fix; the infra re-invocation doesn't count);
  - `none / full: $ 0.55`;
  - a run listing two infra ids with one execution session gives plan-caused re-invocations 0;
  - a manifest naming a missing session exits 2 with `measure: no transcript for`.

  Drop the D1-only B/A assertions.
- [ ] **Step 2: Run it and see it fail.** `node test/measure.test.cjs`. Expected: FAIL on the D2
  assertions.
- [ ] **Step 3: Implement.** Keep `readJsonl`, `usageOf`, `times`, `events`, `findSession`,
  `measureSession` and `measureStage` unchanged. Replace `summarize` and `main` to follow the
  manifest above. `findSession` failing becomes the exit-2 line.
- [ ] **Step 4: Run it and see it pass.** Expected: `0 failed`.
- [ ] **Step 5: Log it.** Append the result to `TOOLS/BUILD-LOG.md`.

### Task 6: Blind-review setup for six branches

**Files:**
- Create: `TOOLS/make-blind.sh`
- Test: `TOOLS/test/blind.test.sh`

**Interfaces:**
- Produces: `make-blind.sh <repo> <dest-parent> <branch>...`
  - It shuffles the branches (`shuf`) and gives them letters `P` to `U` in order.
  - For each letter it adds a detached worktree `<dest-parent>/review-<L>` at the branch head,
    with `experiments/` sparse-excluded.
  - It writes `TOOLS/runs/blind-key.txt` with lines `<L>=<branch> <sha>`.
  - Refuses with exit 2 when there are more than 6 branches, when a branch doesn't exist, when
    `blind-key.txt` exists, or when any `review-<L>` exists.

- [ ] **Step 1: Write the failing test.** It uses a temp repo with three branches. It asserts:
  - three worktrees exist, each at its branch's head;
  - the key has three lines whose branches are a permutation of the three;
  - a second run exits 2 because the key exists;
  - an unknown branch exits 2.
- [ ] **Step 2: Run it and see it fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and see it pass.** Expected: `RESULT: N passed, 0 failed`.
- [ ] **Step 5: Log it.** Append the result to `TOOLS/BUILD-LOG.md`.

### Task 7: Manifest template

**Files:**
- Create: `TOOLS/manifest.json`

**Interfaces:**
- Consumes: Task 5's schema.

- [ ] **Step 1: Write the template.** It has the three arms, six runs (`none-1`, `none-2`,
  `round1-1`, `round1-2`, `full-1`, `full-2`) with empty stage lists, empty `shared` stage
  lists, `"base": ""`, `"plugin": ""` and `"notes": []`.
- [ ] **Step 2: Check it.** `node measure.cjs manifest.json` on the empty template prints the
  tables with zeros and exits 0. Empty lists are not missing sessions.

### Task 8: Procedure

**Files:**
- Create: `TOOLS/README.md`

- [ ] **Step 1: Write the README.** It has a table of the tools, one line each, as in D1's
  README, and the procedure in this order:
  1. Brainstorm E3. Write its spec, pinning the command interface exactly. Pass gate 1 and
     commit the spec. That commit is `<base>`.
  2. Write the functional suite with `functional-suite-prompt.md` into
     `scratch/d2-hidden/`. Run `hidden-check.sh <repo at base> scratch/d2-hidden` once. Every
     hidden case is expected to fail at base, since E3 isn't built yet. A case that passes at
     base tests nothing new: examine it and drop it if so.
  3. Run `pin-plugin.sh <repo> <base>`. Raise `cleanupPeriodDays`. Start `keepawake.ps1`.
  4. Create the gate-2 worktree on branch `d2/gate2` from `<base>`, with `experiments/`
     sparse-excluded.
  5. Write the plan with `writing-dag-plans` (normal format), commit it, and run
     `snapshot.sh ... S0`. If the plan has fewer than 12 tasks, stop and tell Brett.
  6. Run `run-audit.sh gate2-r1 ... 1`, then `run-fix.sh fix-r1 ... fix-prompt.md`. Commit and
     run `snapshot.sh ... S1`. If round 1 was READY, S1 is S2: run the full arm only.
  7. For rounds 2 onward, run `run-audit.sh gate2-rN ... N` and `run-fix.sh fix-rN ...` until
     READY or the convergence stop. Commit and run `snapshot.sh ... S2`.
  8. Set the run budget to twice the full arm's planned execution cost, using D1's A
     execution of $13.25 scaled by plan size. Write it into `manifest.json` notes.
  9. Run `make-run.sh` six times. Run in the order none-1, round1-1, full-1, none-2,
     round1-2, full-2, using `run-arm.sh`.
     - On a preflight halt: save the output, run `run-fix.sh <run>-pf ...
       preflight-fix-prompt.md`, commit, record the session under `preflight-fix`, and
       re-invoke.
     - On an infra stop: record the session under `infra`, and re-invoke.
     - After two infra stops in one run: rerun it from a fresh `make-run.sh` with n
       unchanged, after deleting the old branch.
  10. Run `hidden-check.sh <run worktree> scratch/d2-hidden` on all six branches.
  11. Run `make-blind.sh`, then do the six blind reviews with `blind-review-prompt.md`.
  12. Do the finding trace with `trace-prompt.md`. Brett spot-checks at least three rows.
  13. Before scoring, examine any hidden case that fails on all six branches, including both
      full runs. If the suite is wrong, drop the case and say so in the report.
  14. Run `node measure.cjs manifest.json`, and run `audit-stats` over the gate-2 worktree's
      `.audit/` for per-lens counts. A run that hit its budget cap fails hand-off, but its
      hidden check and blind review are still reported. Apply the decision rule from the
      design, write `REPORT.md`, and move `TOOLS` and `d2-hidden` into
      `experiments/d2-gate2-ablation/`.
  15. Pick the merge branch from the full arm, fix its Important findings, merge, and clean
      up.
- [ ] **Step 2: Check it.** Every script named in the README exists in `TOOLS`, with the
  arguments the README gives it. Run each with no arguments and see its usage and exit 2.
