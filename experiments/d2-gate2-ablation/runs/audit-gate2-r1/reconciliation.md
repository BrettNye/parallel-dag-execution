# Reconciliation: gate-2 plan audit of docs/superpowers/plans/2026-11-17-named-tests.md

Artifact: `docs/superpowers/plans/2026-11-17-named-tests.md` (1423 lines, 16 tasks, all `pending`).
Parent spec: `docs/superpowers/specs/2026-11-17-named-tests-design.md` (frozen, gate 1 READY).
Lenses: coverage, dag-integrity, grounding, charter, context-sufficiency, verifiability, coherence,
ambiguity (8/8 ran). Downstream: this plan is the only consumer of the spec; nothing has landed
since dc30ba0 (HEAD), so no finding can be STALE and no fix is time-critical (no task `running`).
World-claims were checked against the supplied ground-truth tables (declared paths; charter
citations: empty). No lens claim contradicts a resolved row.

What I read to adjudicate: the plan (task-verify-args through task-exec-verify, task-implementer-
prompt, task-reviewer-prompts, task-repo-docs, Context); spec L200-430; `git show 76ed77d`
(message and suite diff); `tests/plan-state/plan-state.test.sh:765-780`;
`skills/executing-dag-plans/implementer-prompt.md:1-40, 60-145`;
`skills/executing-dag-plans/SKILL.md:30-80, 98-106`; `merged-reviewer-prompt.md:54-70`;
`quality-reviewer-prompt.md:66-80`; `README.md:118-128`; `plan-format.md:109, :242`.

## Verdict: NOT READY — 4 blocking

### Blocking findings

**B1. task-verify-tests: the Empirical-unknown-1 run names a case that already passes at `76ed77d^`, so a correct `verify-tests` prints `not-red` and exits 1, and the criterion "prints `ok` ... exits 0" cannot be met.**
- Lenses: grounding, verifiability, context-sufficiency, ambiguity, coherence
- Artifact: "`tests: [tests/plan-state/plan-state.test.sh :: round on \"2\" counts to 3]` and `base_sha:` set to the full SHA of `76ed77d^` ... `verify-tests` prints `ok` for that entry and exits 0." (plan L794-796)
- Evidence (union): grounding P2 and verifiability P1 (HEAD suite run against `76ed77d^`'s plan-state) print `PASS: round on "2" counts to 3` and `FAIL: round on "2" writes review_rounds: 3`. Ambiguity probe 1 and context-sufficiency's scratch probe (`rc:out=[0:3]`) agree. I confirmed by reading `git show 76ed77d`: its message says the old `round` "printed 3, wrote nothing". The T31 loop at `tests/plan-state/plan-state.test.sh:771-777` builds exactly `round on "2" counts to 3` (q=`"2"`), which settles coherence's UNVERIFIABLE on the name. Four independent probe paths converge.
- Concrete failure: the opus implementer gets the correct `not-red` label. It either reports the criterion unmet, or "fixes" the labelling or before-tree logic until it says `ok`, which would destroy the red-before guarantee the feature exists for.
- Resolution: J1. Name `tests/plan-state/plan-state.test.sh :: round on "2" writes review_rounds: 3` (red at base, green at HEAD, unique in the file) and expect the label `ok` exactly, not `ok-absent`.

**B2. task-verify-tests / Context call 7: the KILL criterion asserts that the next run's `git worktree prune` clears a killed run's registrations. Prune leaves a registration while its directory exists, and after KILL the directory does exist.**
- Lenses: grounding, verifiability, ambiguity
- Artifact: "\"signals: KILL leaves a registration the next run prunes\": after `kill -KILL` of a running `verify-tests`, the next run ... exits 0 or 1 normally and afterwards `git worktree list` shows only the main tree." (plan L783-785). Call 7: "the registrations are cleared by the next run's `git worktree prune` ... and a temporary directory is left under `${TMPDIR:-/tmp}`" (L114-116).
- Evidence (union): grounding P3, verifiability P3 and ambiguity probe 2 each show `git worktree list` still listing a worktree after `prune` while its directory exists, and clearing it only after `rm -rf` of the directory and a second prune. The plan's own call 7 says the temp dir (which holds `$work/after` and `$work/before`) is left behind.
- Concrete failure: a correct implementation fails the case, because three trees are listed. The tempting fix, making `verify-tests` force-remove worktrees it did not create, would delete the live trees of a `verify-tests` running at the same time for a parallel task in the same repository. That is the plugin's normal mode (verifiability, ambiguity).
- Resolution: J2, option A. Grounding's option (b) (give `verify-tests` a way to remove stale registrations whose directories exist) changes the frozen spec's step-4 design and is out of scope at gate 2.

**B3. task-implementer-prompt: the new `## Named tests` section tells the implementer to act on its task's `tests:` list, but no task makes `tests:` part of what the implementer receives.**
- Lenses: context-sufficiency, ambiguity, coverage (cleared it: row 33 "full"), coherence (cleared the grammar: Checked item 2)
- Artifact: "If your task's YAML block has a `tests:` list, each entry is `<file> :: <case>`." (plan L1043)
- Evidence (union): I read both ends. `implementer-prompt.md:18-19` (MUST receive: the body "everything after the YAML block", and "frontmatter (id, depends_on, files)"). `:88-98` (Task spec renders only `{task.id}`, files, depends_on and `{task.body}`). Context-sufficiency searched every task whose `files:` include implementer-prompt.md or the executor SKILL.md; none adds `tests:` to the context list or the template.
- Concrete failure: in any later plan that uses `tests:`, the implementer cannot evaluate the section's condition, because it sees no YAML block. It gets the exact case strings only if the body happens to repeat them verbatim. A near-miss name gives `not-green`, exit 1, and a fix round against the cap of 3; the names arrive only through the re-dispatch issue list. The spec's "When the task has `tests:`, say the following" is not delivered on the first dispatch.
- Resolution: J4. All edits are inside task-implementer-prompt's existing `files:`.

**B4. task-verify-tests: no criterion pins step 6's exclusion of the task's test files from the before-tree restore, and the `ok-absent` criterion's wording describes the wrong implementation's behaviour.**
- Lenses: verifiability, coherence (out of lens: "whether the ok-absent fixture can occur while the task's finished test file is kept in the before tree")
- Artifact: step 6, "Every `file` path that is not the `<file>` of one of the task's `test` lines is put back to its content at `base_sha`" (L660-664). Criterion: "\"trees: absent before is ok-absent\": a case the suite does not print before the change (the test was added with the task) gives `ok-absent`" (L744-745). mkrepo commits the suite before `base_sha` (L726-729).
- Evidence (union): verifiability walked every listed fixture case. Each gives the same label whether or not the test file is restored: the suite already exists at base in mkrepo, and the space/quote and custom-prefix fixtures do not say whether their suite is new. Coherence asked out of lens whether the `ok-absent` fixture can occur at all; I answered it from the spec (L228-231, L241-244). Under a correct step 6 the before tree holds the finished test file. A case "added with the task" is therefore present before, and mkrepo's fixture (PASS/FAIL per case depending on lib.sh) prints a fail line for it, giving `ok`, not `ok-absent`. In the spec, `ok-absent` means the suite never reached the case. The only discriminating run, EU1, is broken (B1).
- Concrete failure: an implementer who builds the `ok-absent` fixture as worded finds that a correct implementation gives `ok`. The obvious way to make the case pass is to restore the test file too. Every new named case is then absent at base, labelled `ok-absent` and counted ok. A vacuous new test (one that passes on the old code) is never `not-red`. The suite stays green while the feature's core guarantee does nothing for the common case.
- Resolution: J1. Add a regression case that pins the exclusion, and reword the `ok-absent` fixture so that absence comes from the suite stopping early.

### Joint resolutions

**J1 (B1, B4; with D-EU1-oneoff, D-timing, EMP-1). The EU1 run and the before-tree fixtures in task-verify-tests.** One edit to task-verify-tests' criteria:
1. EU1 names `tests/plan-state/plan-state.test.sh :: round on "2" writes review_rounds: 3` and expects the label `ok` exactly. That case was added in 76ed77d, so a wrong step 6 would label it `ok-absent`. An `ok` therefore also proves the before tree kept the finished test file.
2. State that the EU1 run is a one-off made by the implementer and recorded in the `# Untracked files:` header line, not a suite case. It depends on this repo's history and runs the plan-state suite twice. It is made with an explicit Bash timeout of 600000 ms or in the background, and the header line records its wall time (EMP-1).
3. Add a suite case "trees: new case passing on old code is not-red". At base the suite exists without case `y`; the task's commit adds `y`, which passes on the base code. Expect `not-red`, `0 ok, 1 failed` and exit 1.
4. Reword "trees: absent before is ok-absent": the case is absent before because the suite stops before reaching it (for example, it exits at its first line when a file the task creates is missing), not because "the test was added with the task".
Growth: +0 tasks, +0 files, +0 edges, about +8 lines.

**J2 (B2; with D-INT, D-signal-mech, D-child-kill, D-second-signal, D-tmpdir, D-cleanup-sketch). The signal and cleanup criteria in task-verify-tests, and Context calls 6-7.** One rewrite of the signal block:
1. KILL case (option A, from verifiability and ambiguity). It runs under its own `TMPDIR`. After `kill -KILL`, the test deletes the leaked temporary directory, standing in for the OS temp reaper. The next run then exits 0 or 1, and `git worktree list` shows only the main tree. Call 7 becomes "cleared by the next run's `git worktree prune` once the temporary directory is gone; until then they stay listed". State that `verify-tests` never removes a worktree it did not create.
2. The suite starts `verify-tests` for the signal cases with job control on (`set -m`), so INT is not ignored on entry (grounding P4, verifiability P2).
3. The sleeping fixture suite writes a ready marker, and the test waits for it before signalling. The test asserts that `verify-tests` exits well within the suite's sleep (for example within 10 s of a 60 s sleep), which pins call 6's background-and-`wait`. The trap kills the `sh -c` process itself, so `$!` must name `sh -c`, not a `( cd ... )` subshell wrapper (fix the sketch at L720).
4. Second-signal case: name the test-only hook (an environment variable that delays cleanup), and assert exactly one `verify-tests: T1: interrupted` line, so the case can fail when call 5's ignore is missing.
5. The sketch's early exits (`not in a git repository`, `cannot read HEAD`, `is not a commit`) remove `$work`, and the sketch shows where `cleanup failed` is printed.
Growth: +0 tasks, +0 files, +0 edges, about +12 lines.

**J3 (D-tail-stdout, D-before-content, D-usage-range). The verify-tests suite and header, across task-verify-args, task-verify-tests and task-verify-tail.**
1. task-verify-tail states that it updates the earlier exact-stdout cases to compare only the lines before the first `--- ` header. "trees: git stdout never reaches stdout" whitelists label, total, `--- ` and `  | ` lines.
2. "tails: spec example order" gives a.sh's before run a distinctive line, and asserts that the line appears under `--- a.sh (before)` and in no after block.
3. task-verify-tests states that the `# Untracked files:` and `# Bash tool timeout:` header lines go after the "It never writes" line, so task-verify-args' `sed -n '3,5p'` stays correct. If the exit-2 reasons gain "cleanup failure" (coherence), they must stay on header line 5, or the same edit widens the range. Do not switch to `/^# Exit:/`: the header's exit text is two lines, and that address would drop the second one.
Growth: about +6 lines.

**J4 (B3; with D-redispatch, D-rtg-scope). What the implementer receives and what reviewers demand, in task-implementer-prompt and task-reviewer-prompts.**
1. task-implementer-prompt adds "this task's `tests:` entries, when present" to the MUST-receive list (`implementer-prompt.md:19`). It adds a `Named tests:` rendering to `## Task spec` (`{for each entry in task.tests: "  - " + entry}`, omitted when there are none). The new section keys on that rendered list, not on "your task's YAML block". Add one criterion for each.
2. In `## Re-dispatch on review issues`, one line covers a failed named-test check (source "the named-test check", issue list = the `verify-tests` output). Today the template says "the {spec / quality} reviewer found issues" and "Do NOT change anything that the reviewer didn't flag" (`implementer-prompt.md:128-143`).
3. task-reviewer-prompts scopes the "Red-to-green evidence" escalation in `merged-reviewer-prompt.md` ("run the mutation yourself", `:66-68`) to criteria without an `ok` or `ok-absent` named test.
Trade-off for the author: the frozen spec leaves the quality reviewer unchanged. Its own Red-to-green section (`quality-reviewer-prompt.md:68-80`) calls a missing pair ISSUES, and it never sees the `verify-tests` output. The new implementer sentence says "RED-THEN-GREEN ... is still required for acceptance criteria that have no named test". If the implementer reads that as permission to omit the pair for named cases, a split-mode task whose test-bearing criteria are all named can draw a quality ISSUES. The plan-scope fix is wording in the implementer prompt: "for a named case, report its fail line before and its pass line after as the pair". That adds to the spec's "stays, for criteria without named tests" without contradicting it. Whether it reads as reopening the spec is the author's call.
Growth: +0 files (both prompt files are already owned), about +10 lines.

**J5 (D-dispatch-placement, D-cap-rest, D-diagram). The executor SKILL.md text in task-exec-dispatch and task-exec-verify, plus two plan-format.md lines in task-format.**
1. task-exec-dispatch states the layout. Step 4's lead line becomes `4. **Mark running first.** ...`, with `**Dispatch in parallel:** ...` as the next indented paragraph. Alternatively, keep the lead line, make the paragraph the first indented continuation, and drop "before Dispatch is described". The criterion becomes `rg -c '^(4\. |\s*)\*\*Mark running first\.\*\*'`, anchored to the first `4. ` and `5. Continue` lines, not to the second list at SKILL.md:101/:104.
2. task-exec-verify step 3 also edits SKILL.md:78. "the fourth ISSUES verdict" becomes "the fourth ISSUES verdict or failed `verify-tests`", and "`set` rewrites only the status line" becomes "`set` never touches `review_rounds:`". The task also gives the full replacement text of both diagrams.
3. task-format also edits plan-format.md:109 (the `review_rounds` comment) and :242 (the `failed` row) to include a failed `verify-tests`.
Growth: +0 files (plan-format.md is already in task-format's `files:`), about +10 lines.

### Resolution interactions

- **J1.3 (new not-red case) x J3.1 (tail loosens exact stdout):** once task-verify-tail lands, the new case's run prints a `(before)` block, so it is one of the cases J3.1 must loosen. Benign if J3.1 is stated as a rule over all earlier exact-stdout cases rather than as a list.
- **J1.4 (ok-absent from an early-stopping suite) x J3.2 (before-block marker):** the ok-absent fixture's before tail will show the suite's early-exit message, which is what task-reviewer-prompts tells reviewers to judge. Consistent; benign.
- **J1.2 (EU1 records wall time) x task-exec-verify's "about 85 s per run here":** task-exec-verify does not depend on task-verify-tests, so it may land first with the spec's 85 s rationale. If EU1 then records about 4 minutes, the shipped text is wrong and the 600000 ms cap is tight. That surfaces through DONE_WITH_CONCERNS and `/update`; the cap itself is spec-frozen. Benign, but expect a follow-up.
- **J2.1 (KILL test deletes the leaked dir; never remove others' worktrees) x step 4's `git worktree prune`:** prune drops only registrations whose directory is gone, so a concurrent live run's trees are untouched. A KILL case that shared `TMPDIR` with other cases would break their "TMPDIR is empty" assertions until it deleted its leak; the dedicated `TMPDIR` in J2.1 prevents that. Benign as specified.
- **J2.3 (trap kills `sh -c`; exit-time bound) x the orphaned grandchild:**
  - Killing `sh -c` lets `wait` return, so the time bound holds. The suite's own children can survive (ambiguity probe 3, grounding P4).
  - On this host, `rm -rf` of their working directory succeeds (ambiguity probe 3).
  - On Windows, a real suite that holds files open could make `worktree remove` fail, so stderr would show `cleanup failed` as well as `interrupted`. The fixture suite only sleeps, so the cases stay green. That residual stays DEFERRED (D-child-kill).
  - I deliberately do not add a "suite PID is dead" assertion. A portable POSIX script cannot guarantee it without killing its own process group.
- **J2.4 (exactly one `interrupted` line) x call 5 (a failed cleanup prints `cleanup failed`):** if a slow-cleanup hook also made removal fail, stderr would carry both lines. The assertion counts only `interrupted` lines; benign.
- **J3.3 (header-line placement) x coherence's "add cleanup failure to the exit-2 line":** `3,5p` would cut off a third Exit line. J3.3 resolves this by keeping the reasons on line 5 or widening the range in the same edit.
- **J4.1 (render `tests:` for the implementer) x task-exec-verify:** the controller builds each dispatch from `implementer-prompt.md`'s construction rules (SKILL.md:24, :37). No SKILL.md edit is needed and task-exec-verify's files are not touched. Benign.
- **J4.2 (re-dispatch line) x task-exec-verify's exit-1 bullet ("re-dispatch the implementer with the `verify-tests` output as the issue list"):** both must name the same source. Benign if J4.2 says "the named-test check".
- **J4.3 (scope the merged escalation) x the J4 trade-off (implementer reports the pair for named cases too):** if both land, the merged reviewer receives a pair it no longer re-derives, and the quality reviewer receives the pair it requires. Nothing new becomes reachable. If the author declines the trade-off wording, the quality-reviewer ISSUES path in split mode stays reachable (D-rtg-scope).
- **J5.1 (step-4 restructure) x task-exec-verify's last criterion (`rg -c 'Mark running first'` prints 1):** both layouts keep one occurrence. Benign.
- **J5.2 (SKILL.md:78, "`set` never touches `review_rounds:`") x task-base-sha (`set running` inserts `base_sha:`):** the new sentence is true after task-base-sha; the old one was not. Benign; this is the point of the edit.

### Artifact growth

Artifact growth: +0 tasks · +0 files newly in scope · +0 dependency edges · ~+30 lines of artifact text for the four blocking findings (J1, J2.1, J4.1); ~+55 more if the DEFERRED parts of J2-J5 are taken in the same pass.

This is the plan's first gate-2 round. It carries no `## Audit record`, so there is no earlier round to compare for accretion. Lenses raised two optional growths that I do not recommend this round: splitting task-verify-tests into a trees task and a signals task (+1 task, context-sufficiency), and an S17 fixture task (+1 task, +2 fixture files, charter). Much of J2's DEFERRED detail (signal delivery, process groups, cleanup ordering) is the kind of question a running test answers better than plan prose. If a second round's findings live mostly in that detail, stop and let the task's suite settle it.

### Contradictions between lenses

1. **Does the implementer get its named tests? (B3)**
   - Coverage: full (matrix row 33). Coherence: Checked item 2 lists task-implementer-prompt among the 11 tasks that agree on the `tests:` grammar.
   - Context-sufficiency and ambiguity: the implementer is never given the entries.
   - Resolution: context-sufficiency and ambiguity are correct. Coverage and coherence inspected only the producer end, i.e. that the new section states the right rules. The other two traced the consumer end, i.e. what the template actually renders (`implementer-prompt.md:18-19, :88-98`). I read both ends.
2. **Can the EU1 criterion be met? (B1)**
   - Dag-integrity and charter: VERIFIED (`76ed77d^` is a commit, `.scratch/` is ignored). Coherence: the case name is UNVERIFIABLE (it did not trace `$q`).
   - Grounding, verifiability, ambiguity and context-sufficiency: ran the old script and found the case green at base.
   - Resolution: the clean bills checked only that the referents exist, not that the case is red at base. The four probes are complete. I confirmed via `git show 76ed77d` and the T31 loop at `plan-state.test.sh:771-777`.
3. **Is the before-tree step fully covered? (B4)**
   - Coverage: "Steps 5-6" full (row 20).
   - Verifiability: no criterion pins the exclusion.
   - Resolution: they answer different questions. Coverage asked whether a task owns the requirement, which is true. Verifiability asked whether a test can fail on a wrong build, and none can; verifiability is correct on its question. Coherence's out-of-lens note, plus the spec's definition of `ok-absent` (spec L241-244), shows that the `ok-absent` criterion's wording points at the wrong build.
4. **Severity of task-exec-dispatch's placement conflict.**
   - Ambiguity: BLOCKING.
   - Grounding, context-sufficiency, verifiability: DEFERRED. Coverage and dag-integrity raised it out of lens.
   - Resolution: all agree the defect exists (SKILL.md:35 is one line beginning `4. **Dispatch in parallel:**`). I rate it DEFERRED. A layout that satisfies both the prose and the criterion exists (context-sufficiency's restructure, ambiguity's own option A), and the controller behaves the same with every placement. Logged below.
5. **Severity of task-verify-tail breaking earlier exact-stdout cases.**
   - Coherence: BLOCKING, noting the reconciler may downgrade.
   - Verifiability: DEFERRED.
   - Resolution: DEFERRED. task-verify-tail owns the suite in its `files:`, so updating those cases is in scope, and doing so is the only way to meet its own criterion. Nothing is built wrong. Logged below; J3.1 removes the guesswork.
6. **Does killing the subshell wrapper break cleanup on Windows? (D-child-kill)**
   - Grounding F8: the orphaned `sh -c` keeps its working directory inside a worktree, so `worktree remove --force` or `rm -rf` "can fail on Windows". This was inferred, not observed.
   - Ambiguity probe 3: `rm -rf` of the orphan's working directory succeeded on this host; the orphan itself survived.
   - Resolution: ambiguity's direct probe wins on the cleanup claim. Both lenses agree the grandchild survives. The finding stays DEFERRED as an orphaned-process issue, not a cleanup failure.

### Stale vs defect

Nothing has landed since the plan's commit (dc30ba0 is HEAD), and no other plan consumes the spec, so no finding is STALE. All of these are DEFECT, in plan text that will reach implementers as written: B1, B2, B3, B4 and every DEFERRED entry. The UNVERIFIABLE entry is neither.

I also note, without reopening it, one inaccuracy in the spec text. Spec step 4 says prune clears "registrations left by an earlier run that was killed". That holds only once the leaked directory is gone (B2's evidence). The design (prune at step 4) is unaffected; correct the wording if the spec is ever revised.

### Deferred

Plan text and wording:
- D-dispatch-placement: task-exec-dispatch's "before **Dispatch in parallel:**" and its `^\s*\*\*Mark running first` criterion cannot both hold while step 4 is one line. The `4. ` and `5. ` anchors also match SKILL.md:101/:104 (ambiguity, grounding F5, context-sufficiency, verifiability; coverage and dag-integrity out of lens). J5.1.
- D-cap-rest: the fix-round redefinition reaches only the cap's first sentence. SKILL.md:78 ("fourth ISSUES verdict"; "`set` rewrites only the status line", which is false after task-base-sha) and plan-format.md:109, :242 still say reviewer-only (coverage, grounding F7). J5.2-3.
- D-diagram: task-exec-verify's diagram edit leaves "becomes" and "under it" open (ambiguity). J5.2.
- D-redispatch: the re-dispatch template speaks only of reviewers (coverage, context-sufficiency). J4.2.
- D-rtg-scope: the merged reviewer's "run the mutation yourself" and "Red-to-green evidence present" are unscoped beside "do not re-run or re-derive" (coverage). The frozen quality reviewer has the same rule (`quality-reviewer-prompt.md:68-80`, read while adjudicating) and can call a named-only task's missing pair ISSUES. J4.3 and its trade-off.
- D-agents: the "You receive" lists in `agents/dag-spec-reviewer.md` and `agents/dag-merged-reviewer.md` omit the check output, and no task owns those files (grounding F9).
- D-format-labels: task-format gets only the label names, not their meanings and order. It is a root task and never sees task-verify-tests (context-sufficiency).
- D-readme: task-repo-docs leaves README.md:120 ("The four helper scripts") and the suite command list (:122-127) stale (coverage, context-sufficiency).
- D-call8-paths: call 8 names `writing-dag-plans/SKILL.md` and the others without the `skills/` prefix; the ground-truth table resolves them ABSENT (coherence).
- D-last-three: "see the last three criteria" points at four bullets (coherence).
- D-four-cases: "the four cases above" follows five quoted case names (context-sufficiency, coherence).
- D-tests-cmd-sketch: task-tests-cmd's sketch and its criterion define "tests: prints the whole record" differently, and the sketch is not marked illustrative (ambiguity).
- D-r16-signature: task-tests-cmd calls `r16plan(2)` (a stderr mode) that task-tests-field's `r16task(t, say)` design does not have (coherence).
- D-awk-restate: task-verify-tests and task-verify-tail do not restate the awk portability rule, and CLAUDE.md lists verify-tests only after task-repo-docs (coverage).

Verify-tests suite and script:
- D-tail-stdout: task-verify-tail's blocks break task-verify-tests' exact-stdout and git-stdout cases, and no rule says how to update them (coherence, verifiability). J3.1.
- D-before-content: no case checks the content of a `(before)` block (verifiability). J3.2.
- D-usage-range: `sed -n '3,5p'` against header lines that task-verify-tests adds at no stated position (charter, coherence). J3.3.
- D-INT: INT sent to a `verify-tests` started with `&` from a non-interactive bash is ignored on entry (grounding F3, verifiability). J2.2.
- D-signal-mech: no signal case can tell a foreground implementation from call 6's background-and-`wait`, and "mid-run" is not synchronised (verifiability). J2.3.
- D-child-kill: `$!` of `( cd ... && sh -c ... ) &` names the subshell, so the trap does not stop the suite (grounding F8; charter and ambiguity out of lens). J2.3; the orphan residual remains.
- D-second-signal: signals sent "back to back" may never land inside cleanup, and the asserted outcome cannot fail (ambiguity). J2.4.
- D-cleanup-sketch: the sketch's early exits leak `$work`, and nothing prints `cleanup failed` (coherence). J2.5.
- D-tmpdir: "TMPDIR is empty" passes if `verify-tests` never uses `TMPDIR` (verifiability).
- D-shared-tree: "trees: shared tree untouched" passes on a crash (verifiability).
- D-eu2-probe: the EU2 probe log is never cleared first, and an orphaned probe reads as KILL (verifiability).
- D-cr-check: the CR-byte check passes when `git show` fails (verifiability).
- D-rg-guard: the new suite's shape omits the `command -v rg` guard that exits 2 (charter).
- D-size: task-verify-tests is large for one implementer turn; splitting it is optional (context-sufficiency).
- D-EU1-oneoff: unclear whether the EU1 repository run is a suite case or a one-off (ambiguity). J1.2.
- D-timing: grounding F4 measured 4m06s against the plan's "about 85 s per run here"; EU1 gives no timeout (coherence); charter flags a machine-specific timing in shipped text. J1.2 and EMP-1.

plan-state suite:
- D-resume-case: "base_sha: kept through resume" passes if the second `set running` is refused (verifiability).
- D-illegal-order: "illegal move refused before git" cannot tell the two orderings apart unless the `done` task has `tests:` (verifiability).
- D-comment-key: "comment on tests line is block form" passes if the entries are dropped (verifiability).
- D-sketches: task-base-sha's single-file `MODE=setq` never reaches `apply()` (plan-state:365), and the task-tests-field fixture awk turns `files:` items into `tests:` entries (grounding F6).

Plan-wide:
- D-p4-warning: preflight prints a false-positive P4 warning from task-format's example path (dag-integrity; grounding Checked).
- D-s17-fixture: S17 ships with no should-warn/should-pass fixture pair, unlike S11-S16 (charter).

Count: 36 DEFERRED, including the two downgraded BLOCKINGs.

### Empirical unknowns

- **EMP-1. Wall time of the plan-state suite on an uncontended host.**
  - Grounding measured 4m06s for 210 cases, against the spec's "about 85 s".
  - At least three lenses ran this suite or variants of it at the same time, so contention may inflate that figure.
  - If it holds, the EU1 run (two suite runs plus two worktrees) is close to the 600000 ms ceiling.
  - Settled by: `time bash tests/plan-state/plan-state.test.sh` on an idle host, then the EU1 run itself.
  - Owner: task-verify-tests. Its `files:` own the script whose header records EU1.
  - Acceptance criterion:
    - the EU1 run is made with an explicit Bash timeout of 600000 ms, or in the background;
    - the `# Untracked files:` header line records its wall time;
    - if it exceeds about 540 s, report DONE_WITH_CONCERNS, so that task-exec-verify's text can be amended by `/update`.
- **EMP-2. Whether an orphaned suite process blocks worktree removal on this platform** (contradiction 6). Already covered: task-verify-tests' existing TERM/INT/HUP criteria assert that `git worktree list` shows only the main tree and `TMPDIR` is empty after an interrupt. Running them under Git Bash settles it, so no new criterion is needed.

### Downgrade log

| Lens | Claim | Proposed | Final | Reason |
|---|---|---|---|---|
| ambiguity | task-exec-dispatch's placement instruction and its criterion cannot both be met | BLOCKING | DEFERRED | Missing failure mode. A layout satisfying both exists: lead line `4. **Mark running first.**`, or a reworded instruction. The controller behaves the same with every placement, because the paragraph says "before ... never after". The cost is at most review churn on a mechanical text task. Fix carried in J5.1. |
| coherence | task-verify-tail falsifies task-verify-tests' exact-stdout assertions | BLOCKING | DEFERRED | Missing failure mode. task-verify-tail owns `tests/verify-tests/verify-tests.test.sh`, so updating those cases is in scope and is the only way to meet its own criterion; nothing is built wrong. Duplicated by verifiability at DEFERRED. Fix carried in J3.1. |
| grounding | F2 resolution option (b): give verify-tests a way to remove stale registrations whose directories exist | (an option within a BLOCKING) | not adopted | It changes the frozen spec's step-4 design, which gate 2 may not reopen. The finding itself is upheld as B2 with option A. |
| coherence | the case name `round on "2" counts to 3` cannot be confirmed to exist | UNVERIFIABLE | resolved (exists) | I traced the loop at plan-state.test.sh:771-774. Folded into B1. |

No world-claim was downgraded. None contradicts the ground-truth tables, and every world-claim carries probe output or a `file:line` citation.

### Unverifiable

- **Plugin root of the controller that will run this plan** (dag-integrity, ungrounded).
  - The question: does the executor load `plan-state` and `SKILL.md` from this working tree, or from an installed copy?
  - If from this tree: the plan-state chain tasks rewrite the script the controller calls on every tick, while root tasks run in parallel. A half-written edit could make `check` fail or mis-parse, or the controller could write a bad `set`.
  - Needed: the harness's plugin install path for the run. For example, where the controller resolves "the plugin root", or the `--plugin-dir` the session was launched with.
  - If it is a separate installed copy, nothing changes. If it is this tree, run from a pinned copy of the plugin; the DAG cannot express serialising against the controller.

### Solid

Carried from the lenses' "Checked, no finding" sections, deduped. Do not touch these.
- **DAG:**
  - `plan-state check` exits 0, and the mermaid diagram agrees with `depends_on` (16 nodes, 8 edges). There are no cycles or dangling ids.
  - No two tasks that can run together share a `files:` path.
  - Every edge is justified: the shared-file chains, tests-cmd to verify-args for the `plan-state tests` consumer, and the two P2 edges into exec-verify and repo-docs.
  - The eight roots start wide safely.
  - Sources: dag-integrity, coherence, grounding, context-sufficiency.
- **Coverage:** all 45 spec requirements have an owning task. Each two-surface requirement is owned at both ends: the shared rule 16 predicate, `{verify_tests_output}` (the same name for producer and consumer), case-name uniqueness, `base_sha`, and ok-absent before tail (coverage, coherence).
- **Interface strings:** these match the spec byte for byte: the rule 16/17 messages, `cannot read HEAD for base_sha`, the six-kind `tests` record, `no named tests`, `no base_sha (...)`, `interrupted`, and the label, total and tail formats. All six tasks that name the five labels agree on them and on their precedence (coverage, coherence, ambiguity).
- **`plan-state tests`:** its error order matches plan-state:23-25. `# Exit:` is one line, so `sed -n '3,/^# Exit:/p'` and "usage ends at Exit" are well defined (grounding, ambiguity, verifiability).
- **Doc tasks:** every anchor and count criterion matches the current files, and every "failing check before" prints nothing today. Every S1-S16 and 7-15 enumeration is either owned by a task or kept on purpose per call 8.
- **Charter conformance (charter lens):**
  - `.gitattributes` ownership and block are right.
  - Suite placement fits the CLAUDE.md test glob.
  - The relative `plan-state` path needs no registration.
  - The sketches are POSIX-only, and the script uses no `rg`.
  - File modes are not a defect.
- **`resolve-declared-paths`:** it will not read a `tests:` block as `files:` items (resolve-declared-paths:106-113) (coverage).
- **plan-state criteria:** the task-tests-field, task-base-sha and task-tests-cmd criteria are falsifiable. Each negative case names its message, and whole records are compared for equality (verifiability). The exceptions are listed under Deferred.
- **Signals on this host:** TERM and HUP are trapped in a backgrounded script on this Windows/Git Bash host (verifiability P2, grounding P4).
