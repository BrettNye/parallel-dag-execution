## Lens: verifiability
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (helper scripts are POSIX sh/awk under dash+bash and gawk/mawk/busybox; a suite ends `RESULT: N passed, M failed` and exits non-zero on failure; suites may use rg, scripts may not). No `.claude/audit-charter.md`, no nested CLAUDE.md/AGENTS.md.

Downstream context: all 16 tasks pending and nothing landed after dc30ba0 (given by the dispatcher). So no finding below is STALE or DEFERRED because of downstream work.

Probes: all were run in scratch directories from `mktemp -d` under `$TMPDIR` (C:/Users/Brett/AppData/Local/Temp), outside the repository. Nothing was written into the tree apart from this report.
- P1: `git archive HEAD | tar -x -C $S`, then I overwrote `$S/skills/writing-dag-plans/plan-state` with `git show 76ed77d^:skills/writing-dag-plans/plan-state` and ran `bash tests/plan-state/plan-state.test.sh` in `$S`. Output: `PASS: round on "2" counts to 3`, `FAIL: round on "2" writes review_rounds: 3 (expected [review_rounds: 3] got [review_rounds: "2"])`, `FAIL: round after "2" reaches the cap`, and `RESULT: 205 passed, 5 failed`.
- P2: a script with `trap '...; exit 2' INT TERM HUP; sleep 5 & wait`, started as `sh v.sh &` (and `dash v.sh &`) from `bash -c`, then sent `kill -INT|-TERM|-HUP $!`. Results: INT gives `normal-exit rc=0`, so the trap never ran, under both sh and dash. TERM and HUP give `trapped rc=2`. With `set -m` in the parent, INT gives `trapped rc=2`.
- P3: in a fresh scratch repo, I ran `git worktree add --detach $W/after HEAD` and then `git worktree prune`. `git worktree list` still showed `$W/after`. After `rm -rf $W` and another `git worktree prune`, it showed only the main tree.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| The suite has helpers `ok`/`bad`/`chk`/`has`/`hasnt`, `ps`, `clean_plan`, and `ALTSH` with a NOTE line when dash is missing | task-tests-field, task-verify-args ("follows the plan-state suite's shape") | tests/plan-state/plan-state.test.sh:9-24 | VERIFIED |
| An existing case is named `usage lists rules 1-5 and 7-15` | task-tests-cmd | tests/plan-state/plan-state.test.sh:543 | VERIFIED |
| `# Exit:` is a single header line, so "usage ends at Exit" can pass | task-tests-cmd | skills/writing-dag-plans/plan-state:12, :22 | VERIFIED |
| running -> ready is a legal move (the resume path in "kept through resume") | task-base-sha | skills/writing-dag-plans/plan-state:177 | VERIFIED |
| `clean_plan` marks task-a `done` | task-base-sha sketch | tests/plan-state/plan-state.test.sh:24-49 (task-a `status: done`) | VERIFIED |
| `round on "2" counts to 3` is red at `76ed77d^` and green after | task-verify-tests, Empirical unknown 1 | probe P1; tests/plan-state/plan-state.test.sh:774 | CONTRADICTED |
| The next run's `git worktree prune` clears a KILLed run's registrations | task-verify-tests "signals: KILL…", Context call 7 | probe P3 | CONTRADICTED (only once the leaked directory is gone) |
| A suite can deliver INT to a backgrounded `verify-tests` and see its trap run | task-verify-tests "signals: INT mid-run cleans up" | probe P2 | CONTRADICTED (INT is ignored on entry, so the trap cannot be set) |
| `.scratch/` is ignored | task-verify-tests EU1 | .gitignore:16 | VERIFIED |
| Step-4 sentence "Mark it with `plan-state set <plan> <id> running`." exists | task-exec-dispatch | skills/executing-dag-plans/SKILL.md:35 | VERIFIED |
| The two `implementer DONE` diagrams, "Reading a verdict" at col 0, "Review-round cap", and the ISSUES table row | task-exec-verify | skills/executing-dag-plans/SKILL.md:54, :64, :70, :72, :90 | VERIFIED |
| `## Your output` at col 0 and `RED-THEN-GREEN (required` present | task-implementer-prompt | skills/executing-dag-plans/implementer-prompt.md:66, :73 | VERIFIED |
| "MUST receive" list/sentence and `## Implementation under review` exist | task-reviewer-prompts | spec-reviewer-prompt.md:14, :78; merged-reviewer-prompt.md:8, :80 | VERIFIED |
| `7–15` occurs once (L265); anchors `default_quality_reviewer_hint`, `review_rounds`, "Mixing implementers" | task-format | skills/writing-dag-plans/plan-format.md:32, :109, :112, :263 (`#7–#15`, which `7–15` does not match), :265 | VERIFIED |
| `S1-S16` occurs once; S16 and Detection headings | task-s17 | skills/writing-dag-plans/plan-quality.md:104, :112, :116 | VERIFIED |
| `S1-S16` occurs exactly twice (so `S1-S17` prints 2 afterwards) | task-writer | skills/writing-dag-plans/SKILL.md:69, :214 | VERIFIED |
| `S1-S16` once, `rules 7–15` once, the `review_rounds:` paragraph | task-updater | skills/updating-dag-plans/SKILL.md:25, :59, :86 | VERIFIED |
| The `verifiability` section is bounded by the next `## ` heading | task-lens | skills/auditing-artifacts/lenses-plan.md:179, :186, :208 | VERIFIED |
| `S1–S16` occurs once in README; `git-commit-safe` is in the CLAUDE.md bullet | task-repo-docs | README.md:11; CLAUDE.md:8 | VERIFIED |
| Every doc task's "failing check before the change" prints nothing today | all doc tasks | each `rg` was run: exit 1, no output | VERIFIED |

### Findings

- **BLOCKING** · The on-repo check for Empirical unknown 1 names a case that already passes at `76ed77d^`. A correct `verify-tests` will print `not-red` and exit 1, so this criterion cannot be met.
  - Artifact text: "`tests: [tests/plan-state/plan-state.test.sh :: round on "2" counts to 3]` and `base_sha:` set to the full SHA of `76ed77d^` (the commit before quoted `review_rounds` were rewritten), `verify-tests` prints `ok` for that entry and exits 0."
  - Evidence: probe P1. With the 76ed77d^ script and the HEAD suite, the output is `PASS: round on "2" counts to 3`. The commit message of 76ed77d also says the old `round` "printed 3, wrote nothing". The cases that actually fail at base are `round on "2" writes review_rounds: 3` and `round after "2" reaches the cap` (tests/plan-state/plan-state.test.sh:775-777).
  - Concrete failure: the opus implementer of task-verify-tests gets `not-red`, which is the correct label. Either it reports the criterion unmet, or it "fixes" the labelling or before-tree logic until this run says `ok`. That second path would break the red-before guarantee. Either way the task cannot honestly reach DONE.
  - Resolution: name `tests/plan-state/plan-state.test.sh :: round on "2" writes review_rounds: 3`. P1 shows it red at base, and 76ed77d makes it green. Because that case was added in 76ed77d, the run also proves that the before tree keeps the task's finished test file (see the next finding).

- **BLOCKING** · The KILL criterion asserts something git does not do. `git worktree prune` does not drop a registration while its directory still exists, and after KILL the directory does still exist.
  - Artifact text: "\"signals: KILL leaves a registration the next run prunes\": after `kill -KILL` of a running `verify-tests`, the next run in the same repository exits 0 or 1 normally and afterwards `git worktree list` shows only the main tree." The plan's own Context, call 7, says "a temporary directory is left under `${TMPDIR:-/tmp}`".
  - Evidence: probe P3. After `worktree add` and `worktree prune`, the worktree is still listed. Only after `rm -rf` of the directory does prune clear it. KILL cannot run the trap, so `$work/after` and `$work/before` stay on disk.
  - Concrete failure: a correct implementation fails this case, because `git worktree list` shows the main tree plus the two leaked trees. The obvious way to turn it green is to have `verify-tests` force-remove worktrees it did not create, for example everything under `$TMPDIR` or every detached worktree. That would delete other sessions' worktrees, and this repo runs several sessions in worktrees concurrently. The leaked directory also breaks the later "`TMPDIR` is empty" assertions if they share that TMPDIR.
  - Resolution: undecidable as written. The author must choose one of two options. (A) The test deletes the leaked temporary directory before the next run, standing in for the OS temp reaper, and then asserts that prune clears the registrations. (B) The test asserts only that the next run exits 0 or 1 normally and removes its own trees, so the list equals the main tree plus the two stale entries. Either way, state that `verify-tests` removes only worktrees it created.

- **BLOCKING** · No criterion pins the step-6 exclusion: "every `file` path that is not the `<file>` of one of the task's `test` lines". An implementation that also puts the test files back to `base_sha` passes every listed fixture case. It then labels every new vacuous case `ok-absent`, which counts as ok.
  - Artifact text: "Every `file` path that is not the `<file>` of one of the task's `test` lines is put back to its content at `base_sha` … So the before tree has the task's finished tests". The fixture: "mkrepo … commits, sets T1 running with plan-state (recording base_sha), then commits the change to lib.sh."
  - Evidence: in mkrepo the suite is committed before `base_sha`. So "red then green is ok", "passing before is not-red", "not-green wins over not-red" and "fail line with ( detail" behave the same whether or not the test file is restored. "trees: absent before is ok-absent" gives `ok-absent` under both implementations: the case is either unreached or missing from the restored file. "file with a space and a quote" and "custom command and prefixes" do not say whether their suite is new since base. The one discriminating run is EU1 on this repo, and as written it is broken (first finding).
  - Concrete failure: most named tests are new cases that the task adds to its suite. If an implementation restores the test file, every such case is absent at base, so it gets `ok-absent` and counts as ok. A case that passes on the old code, which is a vacuous test, is never reported `not-red`. The feature's red-before guarantee silently does nothing for new cases, and the suite stays green.
  - Resolution: add a fixture case such as "trees: new case passing on old code is not-red". The task's commit adds case `y` to a suite that existed at base without `y`, and `y` passes on the base code. The expected result is `not-red`, the total `0 ok, 1 failed`, and exit 1. Fixing EU1 as in the first finding covers this in a one-off run on the repo, but not as a regression case.

- **DEFERRED** · "signals: INT mid-run cleans up" cannot pass if the suite starts `verify-tests` in the background without job control. A non-interactive shell's background job inherits INT as ignored, and POSIX does not let a script trap a signal ignored on entry.
  - Artifact text: "\"signals: INT mid-run cleans up\" and \"signals: HUP mid-run cleans up\" do the same for INT and HUP." and "the signal cases also pass when the script runs under `dash`".
  - Evidence: probe P2. Under both sh and dash, a backgrounded script ignores INT (`normal-exit rc=0`). TERM and HUP are trapped. With `set -m` in the parent, INT is trapped.
  - Concrete failure: the INT case is red even when the script is correct. The implementer may wrongly suspect the script's trap, or drop or weaken the case. This is a false red, not a false green, which is why it is DEFERRED.
  - Resolution: say how the suite delivers INT. For example, the suite enables job control (`set -m`) around the signal cases, or uses another launcher that does not leave INT ignored.

- **DEFERRED** · The signal cases cannot see call 6's mechanism. Nothing checks that the suite runs in the background with `wait`, or that the trap stops the `sh -c` child. A foreground implementation passes, only slower.
  - Artifact text: Context call 6, "Run it in the background and `wait` for it, so a signal reaches the trap while a suite runs; the trap stops that process." The criterion: "with a suite that sleeps, sending TERM to the running `verify-tests` makes it exit 2 … and afterwards `git worktree list` shows only the main tree".
  - Evidence: no time bound and no child-liveness assertion appear in any signal criterion (task-verify-tests criteria, plan lines 776-782).
  - Concrete failure: if the suite runs in the foreground, the trap fires only after the sleeping suite returns. The case still exits 2 and cleans up, so it is green. Under a real Bash-tool timeout, though, an escalation to KILL during that delay leaks the trees. An unkilled `sh -c` child also keeps running after `verify-tests` exits. In addition, nothing synchronises "mid-run": a TERM sent before step 4 installs the trap gives a flaky red.
  - Resolution: the sleeping suite writes its PID and a ready-marker file. The test waits for the marker, then sends the signal. It asserts that `verify-tests` exits well within the suite's sleep (for example within 10 s against a 60 s sleep), and that `kill -0 <suite pid>` fails afterwards.

- **DEFERRED** · No case checks the content of a `(before)` block. Every tail case asserts after-block content or headers only.
  - Artifact text: "\"tails: spec example order\" … `--- a.sh (before)` with its tail". The sketch's check filters with `rg '^(---|ok|not|verify)'`, which drops every `  | ` line. "tails: last 20 lines only" and "tails: no output shows placeholder" are both after blocks.
  - Concrete failure: a mix-up between `out/<n>.after` and `out/<n>.before` prints after-tree output under `(before)`, and every case stays green. task-reviewer-prompts tells reviewers to read the `(before)` tail of an `ok-absent` entry to judge whether it was red for the right reason. They would then judge from the wrong run.
  - Resolution: in "tails: spec example order", give a.sh's before run a distinctive line (for example `before-marker`) and assert that it appears under `--- a.sh (before)` and does not appear in the after block.

- **DEFERRED** · "trees: no worktree or temp dir left" and the signal cases check "`TMPDIR` is empty". That check passes if `verify-tests` never put its directory under the test's `TMPDIR`.
  - Artifact text: "the test's own `TMPDIR` directory is empty".
  - Concrete failure: an implementation that hard-codes `/tmp` or ignores `TMPDIR` leaks its work directory, and the check stays green.
  - Resolution: add a positive companion. For example, the fixture suite records `pwd` (the tree root) to a file, and the test asserts that the path starts with the test's `TMPDIR`.

- **DEFERRED** · "trees: shared tree untouched" passes if `verify-tests` crashes before doing anything.
  - Artifact text: "after a run, `git status --porcelain` in the shared tree and the plan's bytes are what they were before the run, and `git rev-parse HEAD` is unchanged."
  - Resolution: pin which run this is: one that exits 0 with an exact expected stdout, or one that has gone through step 6's `git checkout <base> -- <path>`.

- **DEFERRED** · "base_sha: kept through resume" passes if the second `set … running` is refused or crashes.
  - Artifact text: "`set ... ready` then `set ... running` leaves `base_sha:` at the first commit's SHA, and the task has exactly one `base_sha:` line."
  - Concrete failure: if `set running` exits 2 on a task that already has `base_sha:`, every executor resume halts. task-exec-dispatch halts on `set` exit 2. This case stays green.
  - Resolution: also assert that both moves exit 0 and that the task's status line reads `status: running`.

- **DEFERRED** · "base_sha: illegal move refused before git" does not tell the two orderings apart unless the `done` task carries a `tests:` entry.
  - Artifact text: "`set ... running` on a `done` task in a directory with no repository exits 2 with the existing `refused <id>: done -> running` message, not the `cannot read HEAD` one."
  - Evidence: `clean_plan`'s done task-a has no `tests:` (tests/plan-state/plan-state.test.sh:41-49). Without `tests:`, a git failure falls through silently (task-base-sha behaviour item 4), so calling git first still yields the `done -> running` refusal.
  - Resolution: give the `done` task a valid `tests:` entry in this case.

- **DEFERRED** · "rule 16: comment on tests line is block form" passes if the parser drops the entries under `tests:   # cases`.
  - Artifact text: "`tests:   # cases` followed by a valid entry gives no rule 16 line."
  - Concrete failure: the entries are silently not parsed, so `plan-state tests` prints no `test` line, and `verify-tests` prints "no named tests" and exits 0. The named test is never checked.
  - Resolution: make the entry under the commented key a defect that proves it was parsed. For example, use a file outside `files:`, and expect the `test file … is not in its files:` line and no `block list` line.

- **DEFERRED** · The CR-byte check in task-verify-args passes when `git show` fails.
  - Artifact text: "`git show HEAD:skills/executing-dag-plans/verify-tests | od -c | rg -c '\\r'` prints nothing".
  - Concrete failure: if the script is not committed at HEAD, or the path is wrong, `od` gets empty input, nothing matches, and the check reads green.
  - Resolution: pair it with `git cat-file -e HEAD:skills/executing-dag-plans/verify-tests` (exit 0). The `git check-attr` line next to it is the stronger check.

- **DEFERRED** · The Empirical unknown 2 probe can misread its result. The log is never cleared first, and an empty log is put down to KILL, when the signal may instead have gone to a parent while the probe was left running.
  - Artifact text: "Run this probe … then read the log: `sh -c 'trap "echo INT >> /tmp/vt-probe.log; …' …`" and "(INT, TERM, HUP, or nothing, meaning KILL or an untrappable stop)".
  - Concrete failure: a stale log from an earlier attempt reports a signal that did not happen. An empty log from an orphaned probe, still sleeping and later exiting normally, would be recorded in the header as KILL.
  - Resolution: run `rm -f /tmp/vt-probe.log` first. Have the probe write `$$` to the log at start. After the timeout, check with `kill -0` (or `ps`) whether that PID is still alive before concluding KILL.

- **DEFERRED** · task-verify-tail adds output that breaks earlier exact-stdout cases, and does not say how those cases change.
  - Artifact text (task-verify-tests): "Stdout is compared exactly", and "\"trees: git stdout never reaches stdout\": stdout of every run in the suite holds only label and total lines". The task-verify-tail criteria do not mention those cases.
  - Concrete failure: after the tails land, `not-red`, `not-green`, `ambiguous` and `ok-absent` runs print `---` and `  | ` lines. The tail implementer has to loosen the earlier cases with no rule for how, and may weaken the git-stdout whitelist in the process.
  - Resolution: in task-verify-tail, state that those earlier cases compare only the lines before the first `--- ` header, and that the git-stdout case whitelists label, total, `--- ` and `  | ` lines.

- **DEFERRED** · task-exec-dispatch's regex rejects one valid reading of its own placement instruction.
  - Artifact text: "put this paragraph at the start of step 4's text, before \"**Dispatch in parallel:**\" is described". The check: "`rg -c '^\s*\*\*Mark running first\.\*\*' …` prints `1`".
  - Concrete failure: if the paragraph is prepended to the `4. ` line (skills/executing-dag-plans/SKILL.md:35), the line starts with `4. **Mark…` and the check gives a false red. In addition, "after the line starting `4. ` and before the line starting `5. `" matches twice, because there is a second `4. `/`5. ` list at SKILL.md:101/:104.
  - Resolution: say that the paragraph is a separate indented paragraph inside step 4, before the `**Dispatch in parallel:**` text, and anchor the position check to SKILL.md's first `4. ` line.

### Checked, no finding
- task-tests-field: each negative rule-16 case asserts a specific positive message line. "raw entry keeps # and quotes" carries its own positive companion (the `is repeated` line), and "valid tests pass check" asserts no output plus exit 0 on the same fixture.
- task-base-sha: "written on first running" compares against `git rev-parse HEAD`, so it fails on a crash. "refused … with tests" uses `cmp` on the bytes plus a stderr message. "no repository, no tests" asserts `status: running` was written, which is positive. The rule 17 cases name the message.
- task-tests-cmd: whole-record exact equality; the byte-exact trailing space (command substitution strips only newlines); the error-order cases pin both stdout-empty and a stderr message; "bad entry in another task is ignored" asserts exit 0; "usage ends at Exit" is satisfiable because `# Exit:` is one line (plan-state:12).
- task-verify-args: every case asserts exact stdout or a stderr message plus an exit code. The dash fallback prints a NOTE line rather than claiming coverage (`dash` is present here at /usr/bin/dash). The `git check-attr eol` check is a real positive.
- task-verify-tests label cases "red then green", "not-red", "not-green", "not-green wins", "ambiguous", "( detail" (with its `x2` and `exit 0` negatives), "uncommitted change is ignored", "before tree deletes a path", "base_sha not a commit", "cleanup failed" and "ignored dependency": each asserts a positive label or message. TERM and HUP trapping in a backgrounded script works on this Windows/Git Bash host (P2).
- task-verify-tail: "last 20 lines only", "not-red and not-green gives only after", "one file gives after then before", "file order follows tests:", "no output shows placeholder" and "all ok prints no block" (exact stdout) are each falsifiable.
- Doc tasks (exec-dispatch, exec-verify, implementer-prompt, reviewer-prompts, format, s17, writer, updater, lens, repo-docs): every "failing check before" prints nothing today (verified). Every count target is consistent with the current file's occurrences (grounding table). For example, `S1-S17` printing `2` in writing-dag-plans/SKILL.md matches its two current `S1-S16` sites, and `7–15` in plan-format.md occurs only at :265. The quality-reviewer "prints nothing" check is backed by the executor's `files:` scope, as stated.

### Out of lens
- Context call 7 and spec step 4 both say the next run's prune clears a killed run's registrations. P3 shows this holds only once the temporary directory is gone, so the executor text may need the same correction (design/coherence lens).
