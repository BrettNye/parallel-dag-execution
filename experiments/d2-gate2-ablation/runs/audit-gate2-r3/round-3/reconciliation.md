# Reconciliation: gate 2, round 3 (diff-scoped to 5d95374)

## Verdict: READY — 0 blocking

Artifact: `docs/superpowers/plans/2026-11-17-named-tests.md` (plan). Parent spec:
`docs/superpowers/specs/2026-11-17-named-tests-design.md` (frozen). Diff under audit:
`round-3/diff.patch`, task-verify-tests step 6 (plan L662-667) and the new case "trees: new suite
file is kept in the before tree" (plan L759-764). The appended audit-record hunk was not audited.

Lenses run: coverage, grounding, context-sufficiency, verifiability, coherence, ambiguity (6/6).
Carried: dag-integrity, charter (the diff changes no `depends_on`, `files:`, task id or
convention claim; I confirmed `git diff --stat 09fed21 5d95374` touches only the plan, and the
task-verify-tests frontmatter at L634-641 is unchanged). Failed: none.

**Round 2's B1 is resolved.** All six lenses say so independently, by different routes:
- Step 6 now reads "such a path that did not exist at `base_sha` ... is deleted. A test file is
  never put back or deleted, even one the task created." (L664-666). "such a path" binds to the
  previous sentence's non-test `file` paths (coherence, ambiguity, context-sufficiency).
- The new case discriminates the wrong build. A build that deletes the new suite runs a missing
  file (step 7, L673: "a run with no output"), so `y` is absent before and gets `ok-absent`
  (L686), `1 ok, 0 failed`, exit 0. A correct build keeps the suite, `y` passes in both trees,
  and gets `not-red` (L685), `0 ok, 1 failed`, exit 1 (L691-695). Stdout and exit both separate
  them, and `not-red` needs positive evidence that the suite ran, so a crash cannot pass the case
  (verifiability, grounding, coverage, context-sufficiency, ambiguity, coherence).
- The fixture is legal. Rule 16 requires the test file to be in `files:` but checks no
  existence (spec:130-143, which I read), and `set running` reads only HEAD (plan L287-305, per
  verifiability and grounding), so a suite absent at `base_sha` is a valid setup.
- The three step-6 wrong builds are each pinned by exactly one case: restore test files
  (L754-758), delete new test files (L759-764), fail to delete new non-test paths (L781-782)
  (grounding, verifiability, coverage).

World-claims: a ground-truth table was supplied (declared paths; the charter-citation table is
empty). No lens finding contradicts it. The only world-claim made this round is that
`tests/verify-tests/verify-tests.test.sh` and `skills/executing-dag-plans/verify-tests` are new
(grounding), which the table confirms: both ABSENT, declared by create-tasks.

Downstream check: this plan is the spec's only consumer, every task is `pending`, and no
implementation has landed (commits since authoring: 09fed21 and 5d95374, plan only). There was
no proposed BLOCKING to check against downstream artifacts. No owning task is `running`, so
nothing is time-critical.

### Blocking findings

None.

### Joint resolutions

None needed. The two new DEFERRED items (D11, D12 below) touch different text and need no
change to be correct. If the author chooses to apply D11's wording fix, it is one word-level
edit to L781 and does not touch step 6 or the new case.

The optional joint resolutions carried from earlier rounds (JR1.3 for D8, JR2, JR3, and round
1's J2.2-J2.5, J3, J4.2, J4.3, J5) remain unapplied and deferred. Nothing this round changes
them.

### Resolution interactions

- D11's optional edit (L781 "a task file" to "a task file that is not a test file") against the
  applied JR1 (step 6, L662-667, and the new case L759-764): the edit restates step 6's
  "such a path" in the case description. It makes nothing new reachable. Benign.
- D11's optional edit against D8 / JR1.3 (task-reviewer-prompts' "(missing because the task had
  not built it yet)", L1150): different tasks, different text. Applying both makes the reviewer
  text and the case list agree that absence never comes from a missing test file. Benign.
- JR1 (as applied) against D-tail-stdout (accepted): the new case is one more exact-stdout
  `not-red` case whose stdout gains a `(before)` block when task-verify-tail lands
  (L861-863). Same class as the accepted item, not a new one; context-sufficiency, coverage and
  verifiability each checked it. Benign as a new surface; still deferred as before.

### Artifact growth

Artifact growth: +0 tasks · +0 files newly in scope · +0 dependency edges · ~+0 lines of
artifact text (D11's optional fix is a word-level edit to one line; D12 needs no edit).

For the record, the round-3 diff itself grew the plan body by 7 lines (step 6 +1 net, new case
+6); the rest of the 1491 to 1521 line change is the audit record.

Convergence: the plan has converged. Blocking count across gate-2 rounds: 4, then 1, then 0.
This round's findings are all DEFERRED (2 new): one in the diff text with no failure (D12) and
one in unchanged adjacent text whose wording the diff made look inconsistent (D11). No further
gate-2 round is warranted.

### Contradictions between lenses

No two lenses reached opposite verdicts on a finding. Three questions were raised by one lens as
"out of lens" and cleared by another; I adjudicated each so none collapses silently.

1. **Is "A test file" (L665) open to a test-like-path reading?**
   - Coverage (out of lens, not a finding): it could be read as any test-like file, such as a
     fixture in `files:`; on that reading a deleted fixture would be kept, against spec:244.
   - Ambiguity and context-sufficiency (both Checked, no finding): the sentence before it
     defines the class as "the `<file>` of one of the task's `test` lines" (L662-663), and
     verify-tests' only input is `plan-state tests` output (spec:214-216), which carries no
     notion of a test-like path.
   - Resolution: no finding. I read L662-666. The term is defined one sentence earlier, and the
     implementer has no data that would support a path-pattern reading. The clearing verdict
     traced both ends (the definition and the only available input).
2. **Do task-verify-tail's `ok-absent` fixtures need a stated construction?**
   - Ambiguity (out of lens): "tails: spec example order" (L914) and "tails: one file gives after
     then before" (L921) need `ok-absent` entries, and the task body does not say absence can
     now only come from a suite stopping early.
   - Context-sufficiency (Checked, no finding): task-verify-tail depends on task-verify-tests and
     lists the same suite file, which already holds the "trees: absent before is ok-absent"
     fixture built that way (L747-751); a naive fixture fails loudly on the exact label line.
   - Resolution: no finding. I read L842-933. The tails cases compare exact label lines
     (L902-906), so a wrong fixture fails the implementer's own run rather than shipping wrong
     behaviour, and the working construction is in a file the task owns. Nothing is built
     wrong; the cost is at most one fixture rewrite during implementation.
3. **Does the plan's test-file carve-out depart from the frozen spec?**
   - Coherence (out of lens): spec:228-231 says "A path that did not exist at base_sha is
     deleted" without the carve-out.
   - Coverage, grounding, ambiguity, verifiability (all VERIFIED): the spec's own consequence
     sentence, "So the before tree has the task's finished tests" (spec:230), and its ok-absent
     rationale, "a suite for a brand-new script often stops at its first line" (spec:241-242),
     need the new suite to exist in the before tree.
   - Resolution: no finding and no spec reopening. I read spec:225-245. The plan states the
     only reading under which spec:230 and spec:241-242 hold; it clarifies and does not change
     a design decision.

### Stale vs defect

No task has run and no code has landed, so no finding can be STALE.
- D11 (L781 wording): DEFECT, inert. Plan text only; nothing will be built wrong, because the
  parenthetical "its suite reports so on a fail line" forces a non-test file.
- D12 (mkrepo variant mechanism): DEFECT, inert, style-level. Nothing will be built wrong.

### Deferred

New this round (2):
- D11. task-verify-tests: the case "trees: before tree deletes a path new since base" says "a
  task file that did not exist at `base_sha` is absent in the before tree" (L781-782). Read
  alone, that includes test files, and it now sits beside the new case, where a task file new
  since base is kept. Inert: the parenthetical needs the suite present. Optional fix: "a task
  file that is not a test file". Lenses: ambiguity.
- D12. task-verify-tests: the new case's "a mkrepo variant that does not commit the suite before
  `base_sha`" does not say whether to parameterise mkrepo or write a second helper. mkrepo is an
  illustrative sketch (L727-733), as are the fixtures of the neighbouring tree cases. No fix
  needed. Lenses: grounding.

Carried, unchanged (46): round 2's D1-D10 and round 1's 36 items, as listed in
`round-3/prior-findings.md`. None was re-reported. Total DEFERRED: 48.

### Empirical unknowns

- EMP-1 (still open): the plan-state suite's wall time (4m06s observed against "about 85 s per
  run"). Owned by task-verify-tests' EU1 one-off (L811-827) as an acceptance criterion; settled
  by the implementer's timed run of `verify-tests` on this repository as that criterion states.
  D9 (the 540 s trigger may not fire) is still deferred; nothing this round changes it.
- EMP-2: settled in round 2 by the existing signal tests.
- No new empirical unknowns.

Open author decision, unchanged: J4 (whether the implementer prompt tells named cases to report
their fail and pass lines as the RED-THEN-GREEN pair).

### Downgrade log

None. No lens proposed a BLOCKING. Both proposed DEFERRED items are kept at DEFERRED. The three
"out of lens" notes above were never proposed as findings; they are recorded and adjudicated in
"Contradictions between lenses", not dropped.

### Unverifiable

None.

### Solid

Verified this round, deduped. Do not touch.
- **Round-2 B1 fix, step 6 (L662-667):** "such a path" limits deletion to non-test paths; the
  exemption covers test files the task modified and those it created; the text agrees with
  spec:228-231 and :241-244. (all six lenses)
- **New case (L759-764):** discriminating on stdout and exit, cannot pass on a crash, a legal
  fixture under rule 16 and `set running`, name unique (L759 only; I confirmed with `rg`).
  (all six lenses)
- **Neighbouring cases still agree with step 6:** "trees: absent before is ok-absent"
  (L747-751), "trees: new case passing on old code is not-red" (L754-758), "trees: before tree
  deletes a path new since base" (L781-782, wording aside, see D11), and the EU1 one-off
  (L819-822). (all six lenses)
- **Step 7's missing-file rule (L673)** still holds; in the before tree it now applies only to a
  test file also missing at HEAD. (coherence, context-sufficiency)
- **Dependents:** task-verify-tail's block rules key on labels only (L858-871), and "tails: no
  output shows placeholder" stays reachable; task-reviewer-prompts and the implementer-facing
  summary (L1089, "with your finished test files") agree, apart from the accepted D8. (all six
  lenses)
- **No second surface restates step 6:** only Context L48 mentions the before tree, without the
  rule. (coverage, coherence, verifiability, ambiguity)
- **Structure:** unchanged by the diff (16 nodes, 8 edges; dag-integrity carried). (coherence)
- Round 2's solid list stands in full.
