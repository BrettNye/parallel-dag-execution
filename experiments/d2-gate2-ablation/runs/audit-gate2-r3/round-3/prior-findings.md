# Prior finding set for gate 2, round 3 (diff-scoped)

Round 3 audits commit 5d95374, which is the author's fix for round 2's single blocker (B1 below). Diff: round-3/diff.patch. Only the plan body is in scope; the appended audit-record entry is not.

## Blocking in round 2: the round-3 diff is the author's fix for this. Do not re-report the original defect. Report only if the fix itself is wrong or incomplete, or if it introduces a new defect.

- B1 (round 2) task-verify-tests: step 6's deletion clause ("a path that did not exist at base_sha ... is deleted") was not limited to non-test paths, and no case covered a test file the task creates. Prescribed fix JR1: (1) "such a path" plus "A test file is never put back or deleted, even one the task created."; (2) new case "trees: new suite file is kept in the before tree". JR1 part 3 (D8, reviewer parenthetical in task-reviewer-prompts) was optional and was NOT applied; it remains DEFERRED.

## Accepted as DEFERRED in round 2: do not re-report (not applied; JR2, JR3 and JR1.3 remain deferred)

task-implementer-prompt (text the B3 fix created):
- D1. "If the Task spec above lists `Named tests:`" points up; the Task spec is below (implementer-prompt.md:66 against :88). Lenses: grounding F1, context-sufficiency F1, coherence F1, ambiguity F2, verifiability (out of lens). Five-lens corroboration. JR2.1.
- D2. "Omitted when the task has no `tests:`" is in plan prose only; the snippet and the criteria lack an omit directive in the :108 style. Lenses: coverage, ambiguity F3, verifiability F4(b); context-sufficiency cleared it (Contradiction 2). JR2.2.
- D3. The criteria are loose. The MUST-receive line is bounded only by `^## Task spec`, and the condition is pinned only by a negative match that is already true today. Lenses: verifiability F4(a)(c), grounding (out of lens on (c)). JR2.3.
- D10. `agents/dag-implementer.md:12` lists the implementer's input as "`id`, `depends_on`, `files`, body, acceptance criteria", without named tests, and no task owns the file. It is the implementer counterpart of D-agents. Lenses: coverage (out of lens).

task-verify-tests:
- D4. EU1 writes `tests: [ ... ]` in flow form, which rule 16 refuses (spec:70-72; plan L166-167, L260). Copying it gives exit 2 with a stderr line that names the cause. Lenses: grounding F2, ambiguity F1. JR3.1.
- D6. The KILL case never asserts that a registration existed before the leak was deleted, so it passes without prune if the KILL lands before `worktree add`. This is the new precondition piece next to D-signal-mech. Lenses: verifiability F2.
- D7. No case pins "never removes a worktree it did not create"; "only the main tree" also accepts a build that removes every non-main worktree. Lenses: verifiability F3, ambiguity (out of lens).
- D9. The EU1 540 s trigger does not serve its stated purpose. At EMP-1's ~246 s per suite run, the total (~490 s) stays under it and "about 85 s per run" ships uncorrected. This is the new sentence next to D-timing. Lenses: ambiguity F4. JR3.2.

Context and reviewer text:
- D5. Call 7's "The implementer reports that as DONE_WITH_CONCERNS" lost its antecedent when the never-removes sentence was inserted. It is inert, because implementers do not see Context. Lenses: coherence F3, ambiguity F5.
- D8. task-reviewer-prompts' "(missing because the task had not built it yet)" now sits uneasily beside the rewritten ok-absent case, and it fits B1's wrong-build output. Lenses: coherence F2. JR1.3.


## Round 1 findings (all carried)

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

## Round-2 solid (verified; do not touch)


What the lenses verified, deduped. Do not touch these.
- **B1 fix (round-1 B1):** `round on "2" writes review_rounds: 3` exists once per run (plan-state.test.sh:775, inside a two-value loop) and was added in `76ed77d`. It prints a fail line with ` (` detail at `76ed77d^` and passes at HEAD, so "`ok` exactly (not `ok-absent`)" is reachable and discriminating. `76ed77d^` = 1757d4db7e16. `.scratch/` is ignored (.gitignore:16). (grounding, verifiability, context-sufficiency, ambiguity, coherence)
- **B2 fix:** `git worktree prune` behaves as call 7, step 4 and the KILL case now say, probed twice. Deleting the leaked `mktemp -d` directory, which holds both trees, lets one prune clear both. The KILL case's own `TMPDIR` keeps its leak away from the other cases' "TMPDIR is empty" checks. A correct build can now pass. The sketch's cleanup removes only `$work/after` and `$work/before`, which is consistent with the never-removes rule. (grounding, verifiability, coverage, coherence, ambiguity, context-sufficiency)
- **B3 fix:** the anchors `implementer-prompt.md:19`, :88, :94 and :96 exist and are unique. The `tests:. entries, when present` regex matches the backtick. `^Named tests:$` counts 1 after the edit. SKILL.md has no second field list for the implementer prompt, so no second surface is unowned. The re-dispatch path carries the rendered list over. The edits cover every clause of spec:338-341. (all six lenses)
- **B4 fix (as far as it goes):** the new not-red case discriminates the revert-existing-test-file build (exact stdout plus exit 1). The rewritten ok-absent case matches spec:241-244 and cannot pass on a crash. "Before tree deletes a path new since base" agrees with step 6. (verifiability, ambiguity, coverage, context-sufficiency, coherence)
- **Step 4 prose and call 7:** they describe git accurately, ask `verify-tests` to delete nothing, and agree with spec:221-222, :300 and the concurrency anti-goal. (coverage, ambiguity, verifiability)
- **EU1 one-off:** it resolves D-EU1-oneoff. The 540 s threshold sits under the 600000 ms timeout, and "about 85 s per run" is a verbatim substring of task-exec-verify. The `/update` route is right, because task-exec-verify does not depend on task-verify-tests. (coherence, context-sufficiency, coverage)
- **Structure:** 16 nodes and 8 edges match all `depends_on` lines, and the six split-mode tasks match call 3. The diff touched neither. (coherence; dag-integrity carried)
