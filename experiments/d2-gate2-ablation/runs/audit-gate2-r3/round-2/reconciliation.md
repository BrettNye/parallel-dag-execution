# Reconciliation: gate-2 plan audit, round 2 (diff-scoped), docs/superpowers/plans/2026-11-17-named-tests.md

Artifact: `docs/superpowers/plans/2026-11-17-named-tests.md` (1491 lines, 16 tasks, all `pending`), at commit 09fed21.
Parent spec: `docs/superpowers/specs/2026-11-17-named-tests-design.md` (frozen).
Scope: the dc30ba0..09fed21 diff (Context call 7; task-verify-tests step 4, the ok-absent, new not-red, KILL and EU1 criteria; task-implementer-prompt's Implementation and criteria) and what depends on it.
Lenses run: coverage, grounding, context-sufficiency, verifiability, coherence, ambiguity (6/6 reported). Carried from round 1: dag-integrity and charter. The diff changes no `depends_on`, `files:`, task id, convention or enforcement claim, so their verdicts stand.
Downstream: this plan is the spec's only consumer. No code has landed and no task is `running`, so nothing is STALE and no fix is time-critical.
World-claims were checked against the supplied ground-truth table (declared paths; charter citations empty). No lens claim contradicts a resolved row. The `.audit/.../reconciliation.md` ABSENT row is plan-relative and was ignored, as instructed.

What I read to adjudicate:
- plan L640-835 (task-verify-tests in full) and L1050-1165 (task-implementer-prompt, task-reviewer-prompts);
- spec L55-100 (the `tests:` grammar), L130-137 (rule 16), L215-247 (verify-tests steps 1-9) and L336-348 (the prompts);
- `skills/executing-dag-plans/implementer-prompt.md` (headings and :16-23);
- `agents/dag-implementer.md:1-14`;
- round-1 `reconciliation.md` L1-140 (B4 and J1), to check whether a finding is a duplicate or new.

## Verdict: NOT READY — 1 blocking

### Blocking findings

**B1. task-verify-tests: the B4 fix pins "keep the task's test files" only for a test file that already existed at `base_sha`. Step 6's deletion clause is unscoped, and no case covers a test file the task creates. An implementation that deletes new test files from the before tree passes every case and labels every case of a brand-new suite `ok-absent`, including vacuous ones.**
- Lenses: verifiability (BLOCKING); coherence (DEFERRED F2, supplies the missing-backstop half; see below). Coverage, context-sufficiency, ambiguity, coherence and grounding each cleared the B4 fix as complete (Contradiction 1).
- Artifact text: step 6, "Every `file` path that is not the `<file>` of one of the task's `test` lines is put back to its content at `base_sha` (`git -C <before> checkout <base> -- <path>`); a path that did not exist at `base_sha` (`git cat-file -e <base>:<path>` fails) is deleted." (plan L662-665). New case: "at `base_sha` the suite exists without case `y`" (L753). Step 7: "A `<file>` that does not exist in a tree counts as a run with no output." (L672)
- Evidence (union):
  - Verifiability walked every task-verify-tests criterion (L744-831) and ran a second keyword search (`new since|did not exist|added with the task|new suite|new test file|brand-new|does not exist in a tree`).
    - Every fixture with a named test file commits the suite before `base_sha`: mkrepo (L728-731), the new not-red case (L753), and EU1, where `76ed77d` only modifies an existing suite.
    - The only "new since base" case makes the new path a non-test file (L774-775).
  - I added three facts:
    - Rule 16 requires every test `<file>` to be in the task's `files:` (spec:134-136). So step 6's loop always visits test files, new ones included.
    - Step 7 gives a deleted test file a ready-made, non-crashing outcome, so the wrong build fails nothing.
    - The spec's intent is unambiguous ("So the before tree has the task's finished tests", spec:230-231; "a suite for a brand-new script often stops at its first line when the script is missing", spec:242). The plan's step 6 copies the spec's unscoped second clause into an implementation-level instruction.
  - Cross-lens (coherence F2 + verifiability): the reviewer backstop does not catch the wrong build. Under it, the before tail of a brand-new suite is empty, because the file is absent and so produces no output. task-reviewer-prompts tells reviewers that the right reason for `ok-absent` is "missing because the task had not built it yet" (plan L1143). An empty tail for a suite the task created fits that sentence.
- Concrete failure: an implementer writes step 6 as "for each `files:` path: if absent at base, delete; else if not a test file, check out the base version". That build passes L744-831 and the EU1 run. In real use the common shape is a task that creates its own suite, as task-verify-args does with `tests/verify-tests/verify-tests.test.sh`. For such a task every named case is absent before and labelled `ok-absent` (counted ok). A test that passes on the old code is never `not-red`, and `verify-tests` exits 0. This is the failure round 1 named for B4 ("every new named case is then absent at base, labelled `ok-absent` ... the feature's core guarantee does nothing for the common case"). The round-1 fix closed it for one wrong build and left it open for this one.
- Why it stands after the downstream check: no downstream plan restates step 6, and no code has landed. It is in scope as an incomplete fix of a round-1 blocker, not a new area.
- Resolution: JR1 below. Scope the deletion clause to non-test paths, and add one suite case. About +6 lines, +0 tasks, +0 files, +0 edges.

### Joint resolutions

**JR1 (B1; with D8 reviewer wording). Before-tree scope in task-verify-tests, plus one parenthetical in task-reviewer-prompts.**
1. Step 6 (L662-665): "...is put back to its content at `base_sha` (...); **such** a path that did not exist at `base_sha` (...) is deleted. A test file is never put back or deleted, even one the task created." The spec intends this (spec:230-231) and does not forbid it, so the spec is not reopened.
2. New case after L757: "trees: new suite file is kept in the before tree". At `base_sha` the suite file does not exist. It is in T1's `files:`, as rule 16 requires. The task's commit adds it with case `y`, which passes on the base code. Expect `not-red`, `0 ok, 1 failed`, exit 1. An implementation that deletes new test files from the before tree would label `y` `ok-absent`. This needs a mkrepo variant that does not commit the suite before `base_sha`.
3. (Optional, DEFERRED D8) In task-reviewer-prompts' literal section (L1143), change "(missing because the task had not built it yet)" to "(the code the case exercises did not exist yet, so the suite stopped before the case)". Then the reviewer text matches the correct build, and an empty before tail reads as suspect.
Growth: +0 tasks, +0 files, +0 edges, about +6 lines (+1 more if part 3 is taken).

**JR2 (D1, D2, D3; optional, all DEFERRED). task-implementer-prompt's rendering and its criteria, the text the B3 fix created.** One edit:
1. In the literal `## Named tests` section (L1076), change "the Task spec above" to "the Task spec below". The section's placement criterion (before `^## Your output`, which is :66 against `## Task spec` at :88) fixes the order, so the word is the cheaper edit.
2. In the edit-2 snippet (L1066-1069), add a third line in the :108 style, `{if task has no tests: omit the two lines above}`, and require it in the criterion. Place it after the for-each line, so "the next line is `{for each ...}`" still holds and all three lines lie between `^## Task spec` and `^### Body`.
3. Bound the MUST-receive line by `^## Prompt template`, not `^## Task spec`. Add a positive count check, pattern `lists .Named tests:.`, expecting 1, beside the negative one.
Growth: about +4 lines. Recommended in the same pass as JR1. Part 1 is one word, fixes text the B3 fix introduced, and has five-lens corroboration.

**JR3 (D4, D9; optional). The EU1 one-off run's wording in task-verify-tests.**
1. Write the declaration in block form: "`tests:` with one block-form entry, `  - tests/plan-state/plan-state.test.sh :: round on "2" writes review_rounds: 3`". The raw-entry grammar (spec:76-79) takes the `: ` and the quotes literally, so block form is all that is needed.
2. Tie the DONE_WITH_CONCERNS trigger to its purpose. Report when the per-suite time is well above 85 s, which is what `/update` should amend. Report separately when the total nears the 600 s Bash limit, which is a timeout risk. Alternatively, drop the "so that ..." clause.
Growth: about +2 lines.

No other joint clusters. D5 (call 7's antecedent), D6, D7 and D10 are independent one-line fixes, listed under Deferred.

### Resolution interactions

- **JR1.1 (scope deletion to non-test paths) x "trees: before tree deletes a path new since base" (L774-775):** that case's new path is a non-test task file, so it is still deleted. Benign.
- **JR1.1 x the rewritten ok-absent case (L746-750):** its fixture must make the suite stop early because a *code* file the task creates is missing. If the suite file itself were the new file, JR1.1 keeps it, so it would run. The case text already says "a file the task creates", and under JR1 that has to be a non-test file. Benign, but the implementer should know: do not use a new suite file to produce `ok-absent`.
- **JR1.2 (new-suite case) x D-tail-stdout (deferred J3.1):** once task-verify-tail lands, a `not-red` entry prints a `(before)` block, so this case's exact stdout must be loosened too. This adds one case to the set D-tail-stdout already covers, as round 1 found for J1.3. Benign if task-verify-tail's update is stated as a rule over all earlier exact-stdout cases.
- **JR1.2 x EU1's "the `ok` also shows that the before tree kept the task's finished test file" (L814-815):** that claim stays true, but only for a modified file. JR1.2 now covers the created-file half, so EU1 does not need to change. Benign.
- **JR1.3 (reviewer parenthetical) x JR1.1:** together they close the path where an empty before tail of a new suite is accepted. JR1.1 alone stops the wrong build from existing. JR1.3 alone makes reviewers distrust its output. Neither creates a new reachable state. Benign.
- **JR2.1 ("below") x JR2.2 (omit directive):** with both applied, the section's condition tells a task with entries from one without. With only JR2.1 applied, a task without `tests:` renders an empty `Named tests:` header, and the condition holds with zero entries, which is vacuous and harmless. Benign either way.
- **JR2.2 (omit line) x the existing criterion that `^Named tests:$` counts 1 and the next line is `{for each ...}`:** the omit line goes after the for-each line and does not start with `Named tests:`, so both checks still hold. Benign if the placement is stated.
- **JR2 x D-redispatch (deferred J4.2):** the re-dispatch path reuses "the same task context" (implementer-prompt.md:128), so the rendered list carries over. Benign.
- **D7 resolution (foreign-worktree case) x "trees: no worktree or temp dir left" and the signal cases ("`git worktree list` shows only the main tree"):** a foreign worktree registered in a shared fixture repository would break those assertions. The foreign-worktree case needs its own repository. This is a real collision if D7 is taken. Benign if stated.
- **D6 resolution (assert a registration exists before deleting the leak) x D-signal-mech / J2.3 (ready marker before signalling):** both use the same marker. The precondition only holds once the marker is used. Benign; take them together.
- **JR3.2 (wall-time trigger) x task-exec-verify's "about 85 s per run here" (deferred D-timing, EMP-1):** a per-suite trigger fires on this machine (EMP-1 observed about 246 s per run). It routes the amendment through `/update` without touching task-exec-verify's files. Benign.

### Artifact growth

Artifact growth: +0 tasks · +0 files newly in scope · +0 dependency edges · ~+6 lines of artifact text for the one blocking finding (JR1); ~+7 more if the DEFERRED JR2 and JR3 are taken in the same pass.

Round-over-round: round 1 had 4 blocking findings, and its fixes added about 85 lines (1406 to 1491, including the ~27-line Audit record). Round 2 has 1 blocking finding. The blocking count is falling, so I do not recommend stopping.

Convergence: partial. Every finding except B1 is DEFERRED. B1 is inside the diff's dependents, an incomplete B4 fix, so the round has not fully converged. One accretion pattern to note: 7 of the 10 new DEFERRED items (D1, D2, D3, D4, D5, D6, D9) live in text that the round-1 fixes wrote. That is the "findings live in the text the last fixes created" pattern. After JR1, a round 3 should look only at JR1's ~6-line diff, or be skipped if the author accepts JR1 as written here. A full six-lens pass would most likely find more DEFERRED wording in the new text.

### Contradictions between lenses

1. **Does the B4 fix pin step 6 completely?**
   - Coverage ("the new not-red case ... first owner of spec 6's 'So the before tree has the task's finished tests'"), context-sufficiency ("the fixture is fully specified"), ambiguity ("separates the two readings of step 6"), coherence (contract 2 consistent) and grounding ("contradicts nothing in step 6") all cleared it.
   - Verifiability: BLOCKING. A third reading (delete new test files) is unpinned.
   - Resolution: verifiability is correct.
     - The clearing lenses each checked that the new case discriminates the revert-existing-file build. That is true.
     - None of them traced step 6's second clause across the set of paths it applies to. Rule 16 (spec:134-136) puts every test file in that set. Verifiability enumerated every fixture's base state and found none with a created test file.
     - Ambiguity's "two readings" was correct but incomplete.
   - Read: plan L662-672, L744-831; spec L134-136, L228-244.
2. **Is the missing omit directive a finding?**
   - Context-sufficiency: no finding ("a missing omission line would only render an empty `Named tests:` list, which the section then treats as nothing to do").
   - Coverage, ambiguity, verifiability F4(b): DEFERRED.
   - Resolution: DEFERRED. The lenses agree on the harm, which is none. They disagree only on whether an unpinned clause counts. The plan states "omitted when the task has no `tests:`" in prose but neither the inserted text nor any criterion carries it. The spec says plans without `tests:` behave as today, and an empty header in every dispatch is a change. So the defect is real but inert. Read: implementer-prompt.md:94, :108; plan L1063-1069, L1104-1108.
3. **Is the KILL case falsifiable?**
   - Ambiguity: "falsifiable as reworded".
   - Verifiability F2: falsifiable only if the KILL lands after `worktree add`, and nothing asserts that it did.
   - Resolution: both are right about different preconditions. Verifiability's evidence is more complete (probe P1, plus the missing precondition). DEFERRED, next to D-signal-mech.
4. **Call 7's "never removes a worktree it did not create".**
   - Coverage: no finding (a restriction, not over-build).
   - Verifiability F3 and ambiguity out of lens: no case would fail on a violation.
   - Resolution: these answer different questions, and both hold. DEFERRED. Nothing in the text now pushes toward the violation, because the KILL case can pass through prune once the leak is deleted, which removes round 1's temptation.

### Stale vs defect

Nothing has landed since the plan was authored (09fed21 is a plan-only edit), and the plan is the spec's only consumer, so nothing is STALE.
- DEFECT: B1, D1-D10. All are plan text that reaches implementers or reviewers as written. D5 sits in the Context section, which implementers do not receive, so it is inert.
- STALE: none.

### Deferred

New this round (10). With the 36 carried from round 1, the total is 46.

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

Carried from round 1, accepted, not re-reported: 36 items (prior-findings.md), including D-timing, D-signal-mech, D-tail-stdout, D-agents and D-redispatch, which the items above sit next to.

### Empirical unknowns

- **EMP-1 (open):** plan-state suite wall time (4m06s observed against "about 85 s"). Owner: task-verify-tests' EU1 one-off run, which now records wall time in the `# Untracked files:` header line. Settling command: the EU1 run itself, timed. D9 notes that its DONE_WITH_CONCERNS trigger may not fire at the observed time; JR3.2 fixes that.
- **EMP-2 (open):** an orphaned process blocking worktree removal. Settled by the existing signal tests in task-verify-tests.
- **Settled this round:** whether the new EU1 case is red at `76ed77d^` and green at HEAD.
  - Grounding's probe: `FAIL: round on "2" writes review_rounds: 3 (expected [review_rounds: 3] got [review_rounds: "2"])` at base.
  - Verifiability P2: the same at base, and all six T31 cases PASS at HEAD.
  - Grounding and verifiability P1 also settled whether `git worktree prune` keeps a registration while its directory exists and drops it once the directory is gone (git 2.56.0.windows.1).
- No new empirical unknowns.

Open author decision, unchanged: **J4 trade-off.** Should the implementer prompt tell a named case to report its fail-before and pass-after lines as the RED-THEN-GREEN pair, so the unchanged quality reviewer does not call it ISSUES?

### Downgrade log

None. Every lens severity was kept.
- Verifiability's BLOCKING (B1) is upheld. The lens said the reconciler might downgrade it, because the likelier wrong build is now caught. I declined, for four reasons: the unscoped clause is a text-driven path to the remaining wrong build; rule 16 sends every new test file through it; step 7 makes it silent; and the reviewer text does not catch it. Round 1 upheld the same concrete failure as B4.
- All DEFERRED proposals stay DEFERRED.
- No promotions. Coherence F2 (D8) supplies evidence for B1 but is not itself promoted, because under a correct build its ambiguity is harmless.

### Unverifiable

None. No lens claim contradicts the ground-truth table, and every world-claim carries a `file:line` citation or probe output.

### Solid

What the lenses verified, deduped. Do not touch these.
- **B1 fix (round-1 B1):** `round on "2" writes review_rounds: 3` exists once per run (plan-state.test.sh:775, inside a two-value loop) and was added in `76ed77d`. It prints a fail line with ` (` detail at `76ed77d^` and passes at HEAD, so "`ok` exactly (not `ok-absent`)" is reachable and discriminating. `76ed77d^` = 1757d4db7e16. `.scratch/` is ignored (.gitignore:16). (grounding, verifiability, context-sufficiency, ambiguity, coherence)
- **B2 fix:** `git worktree prune` behaves as call 7, step 4 and the KILL case now say, probed twice. Deleting the leaked `mktemp -d` directory, which holds both trees, lets one prune clear both. The KILL case's own `TMPDIR` keeps its leak away from the other cases' "TMPDIR is empty" checks. A correct build can now pass. The sketch's cleanup removes only `$work/after` and `$work/before`, which is consistent with the never-removes rule. (grounding, verifiability, coverage, coherence, ambiguity, context-sufficiency)
- **B3 fix:** the anchors `implementer-prompt.md:19`, :88, :94 and :96 exist and are unique. The `tests:. entries, when present` regex matches the backtick. `^Named tests:$` counts 1 after the edit. SKILL.md has no second field list for the implementer prompt, so no second surface is unowned. The re-dispatch path carries the rendered list over. The edits cover every clause of spec:338-341. (all six lenses)
- **B4 fix (as far as it goes):** the new not-red case discriminates the revert-existing-test-file build (exact stdout plus exit 1). The rewritten ok-absent case matches spec:241-244 and cannot pass on a crash. "Before tree deletes a path new since base" agrees with step 6. (verifiability, ambiguity, coverage, context-sufficiency, coherence)
- **Step 4 prose and call 7:** they describe git accurately, ask `verify-tests` to delete nothing, and agree with spec:221-222, :300 and the concurrency anti-goal. (coverage, ambiguity, verifiability)
- **EU1 one-off:** it resolves D-EU1-oneoff. The 540 s threshold sits under the 600000 ms timeout, and "about 85 s per run" is a verbatim substring of task-exec-verify. The `/update` route is right, because task-exec-verify does not depend on task-verify-tests. (coherence, context-sufficiency, coverage)
- **Structure:** 16 nodes and 8 edges match all `depends_on` lines, and the six split-mode tasks match call 3. The diff touched neither. (coherence; dag-integrity carried)
