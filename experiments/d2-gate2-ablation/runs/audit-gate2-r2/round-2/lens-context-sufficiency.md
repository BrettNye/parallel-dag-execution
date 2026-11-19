## Lens: context-sufficiency (gate 2, round 2, diff-scoped: dc30ba0..09fed21)
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (no AGENTS.md, no .claude/audit-charter.md, as stated in dispatch). Ground-truth table read; no EXISTS contradicted.

Downstream context: given. This plan is the only consumer of the spec; all 16 tasks are pending; no code has landed. So any defect in the task bodies reaches an implementer directly. No probes were run; nothing was written in the tree except this report.

Scope: Context call 7 (as it reaches task-verify-tests), task-verify-tests step 4 and the changed criteria (ok-absent, new not-red case, KILL, Empirical unknown 1 run), and task-implementer-prompt's Implementation and criteria. Everything in prior-findings.md was skipped.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| "The implementer MUST receive" list has a frontmatter line at :19 | task-implementer-prompt step 1 | skills/executing-dag-plans/implementer-prompt.md:16-19 | VERIFIED |
| `## Task spec` has a `depends_on:` line, followed by `### Body` | task-implementer-prompt step 2, last criterion | implementer-prompt.md:88, :94, :96 | VERIFIED |
| The new `## Named tests` section goes "right before ## Your output" and says "the Task spec **above**" | task-implementer-prompt step 3 | `## Your output` at implementer-prompt.md:66; `## Task spec` at :88, i.e. below it. The section-order comment at :27-29 puts output format (3) before task spec (4) | CONTRADICTED (see F1) |
| `RED-THEN-GREEN \(required` occurs once, and the new section text does not add a second match | task-implementer-prompt criterion 3 | implementer-prompt.md:73; the new text says "RED-THEN-GREEN report below", which the pattern does not match | VERIFIED |
| The case `round on "2" writes review_rounds: 3` exists and was added in 76ed77d | task-verify-tests EU1 run | tests/plan-state/plan-state.test.sh:771-775 (loop over `'"2"'`); `git show 76ed77d -- tests/plan-state/plan-state.test.sh` shows that line as added (+) | VERIFIED |
| `.scratch/` is ignored | task-verify-tests EU1 run | .gitignore:16 | VERIFIED |
| Call 7's new rule ("never removes a worktree it did not create") reaches the task-verify-tests implementer, who does not see Context | Context call 7 to the KILL criterion | Plan L793-800 restates it inline, with its reason; plan L653-655 (step 4) restates the "once their directories are gone" limit | VERIFIED (inlined) |
| Other task bodies that point at call 7 | plan-wide | `rg -n 'call 7\|Context, call'` finds only L828 (EU2 criterion, pre-existing, and its action "report DONE_WITH_CONCERNS" is stated inline) plus the Audit record | VERIFIED |

### Findings

- **DEFERRED** · The text task-implementer-prompt has inserted verbatim tells every later implementer that the Task spec is "above" the section. In the rendered prompt it is below.
  - Artifact text: step 3, "Inside the prompt template, a new section right before "## Your output"" and the literal section "If the Task spec above lists `Named tests:`, each entry is `<file> :: <case>`."
  - Evidence: `## Your output` is at implementer-prompt.md:66 and `## Task spec`, where step 2 adds the `Named tests:` list, is at implementer-prompt.md:88-94. A section placed right before :66 comes before the Task spec. The template's own order comment (:27-29) fixes output format before task spec.
  - Concrete failure: the task-implementer-prompt implementer has to choose between copying the literal block, which ships a false pointer, and correcting it, which strays from the literal text the reviewer compares against. No criterion checks the word either way. The implementers who later get this prompt are told to look above for a list that is below. An LLM reading the whole prompt will very likely still find it, so nothing should be built wrong. That is why this is DEFERRED.
  - Resolution: change "above" to "below" (or "in the Task spec section") in step 3's literal block.

No blocking findings. The four round-1 blocking fixes (B1-B4) give each affected implementer what it needs without the Context section, the spec or another task.

### Checked, no finding
- **B2 / call 7 to task-verify-tests:** the task body never needed call 7 itself. Step 4 states the prune limit ("once their directories are gone"). The KILL criterion states the test setup: its own `TMPDIR`, and deleting the leak as a stand-in for the OS reaper. It also gives the script rule (never remove a worktree it did not create) and the reason (a concurrent `verify-tests`). An implementer can build and test this from the task body alone.
- **B4 / new not-red case:** the fixture is fully specified: `y` is absent from the suite at `base_sha`, the task's commit adds it, and it passes on the base code. So are the expected label, total and exit, and the wrong implementation it catches (restoring test files gives `ok-absent`). It can be built from the existing mkrepo shape (T1's `files:` already includes `t/demo.test.sh`) with no guessing.
- **ok-absent case:** the case says why the case must be absent before (the suite stops early, for example on a missing file the task creates) and why the simpler fixture no longer works (step 6 keeps the finished test file). It does not clash with "before tree deletes a path new since base": in that case the suite prints a fail line, and here it exits before printing anything.
- **B1 / EU1 one-off run:** the run is now clearly a one-off, not a suite case. The case name, the base commit, the expected exact label `ok`, the Bash timeout (600000 ms or background), where the result goes (`# Untracked files:` header line, wall time included) and the DONE_WITH_CONCERNS threshold (~540 s) are all stated inline. The quote from task-exec-verify ("about 85 s per run") only tells the implementer what `/update` will amend. It does not have to read that task. The case name and its history are grounded in the table above.
- **B3 / task-implementer-prompt:** all three edits name exact anchors that exist (:19, the `depends_on:` line at :94, `### Body` at :96). Each criterion has an `rg` check. The new negative check (`YAML block has a .tests:` prints nothing) pins the change of key from the YAML block to the rendered list. The "omitted when the task has no `tests:`" condition has no literal template form, but the file already has precedents for it (:94 `{... or "[] (root task)"}`, :108 `{if no upstream: omit this section entirely}`). A missing omission line would only render an empty `Named tests:` list, which the section then treats as nothing to do. No finding.
- The Re-dispatch path (implementer-prompt.md:128) reuses "the same task context", so the rendered `Named tests:` list carries over. The reviewer-only wording there is already D-redispatch.

### Out of lens
- task-implementer-prompt step 1's literal `` `- This task's `tests:` entries, when present.` `` nests backticks. Only the criterion's `tests:.` regex shows that a character (the backtick) must follow `tests:` (ambiguity).
