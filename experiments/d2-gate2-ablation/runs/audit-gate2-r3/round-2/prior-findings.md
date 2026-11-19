# Prior finding set (gate 2, round 1, rev 0e7cd18dd18f, commit dc30ba0)

## Blocking in round 1 — the round-2 diff is the author's fix for these. Do not re-report the original defect; report only if the fix itself is wrong, incomplete, or introduces a new defect.

- B1 task-verify-tests: the EU1 repo run named `round on "2" counts to 3`, which already passes at `76ed77d^`, so "prints ok, exits 0" could not be met.
- B2 task-verify-tests / Context call 7: the KILL criterion assumed `git worktree prune` clears a killed run's registration, but prune keeps it while the leaked temp directory exists.
- B3 task-implementer-prompt: the new `## Named tests` section acted on the task's `tests:` list, which the implementer is never given.
- B4 task-verify-tests: no test pinned step 6's 'keep the task's test files' rule.

## Accepted as DEFERRED in round 1 — do not re-report (the author chose to apply only the blocking fixes; the non-blocking joint resolutions J2.2-J2.5, J3, J4.2, J4.3 and J5 were NOT applied and remain deferred)

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

## Open author decision (do not re-report)

- J4 trade-off: the frozen spec leaves the quality reviewer unchanged; its Red-to-green section calls a missing pair ISSUES. Whether the implementer prompt should say 'for a named case, report its fail line before and its pass line after as the pair' is the author's call (spec-reopening question).

## Empirical unknowns already open

- EMP-1 plan-state suite wall time (4m06s observed vs ~85 s); owned by task-verify-tests' EU1 run.
- EMP-2 orphaned process blocking worktree removal; settled by the existing signal tests.
