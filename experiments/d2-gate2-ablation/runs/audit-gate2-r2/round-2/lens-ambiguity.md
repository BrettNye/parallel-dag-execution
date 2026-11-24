## Lens: ambiguity (gate 2, round 2, diff-scoped: dc30ba0..09fed21)
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (no AGENTS.md, no .claude/audit-charter.md). Ground-truth table read; no path below contradicts an EXISTS.

Downstream context: given. This plan is the spec's only consumer, all 16 tasks are pending, and no code has landed, so nothing below is STALE. No probes were run. Nothing was written in the tree except this report.

Scope: Context call 7; task-verify-tests (step 4, the ok-absent case, the new not-red case, the KILL case, the EU1 run); task-implementer-prompt (Implementation and criteria). Prior findings were not re-reported.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| The "MUST receive" frontmatter line is implementer-prompt.md:19 | task-implementer-prompt, edit 1 | skills/executing-dag-plans/implementer-prompt.md:19 | VERIFIED |
| `## Task spec` has a `depends_on:` line, followed by `### Body` | edit 2 and its criterion | implementer-prompt.md:88, :94, :96 | VERIFIED |
| The new section "right before ## Your output" sits *above* the Task spec | edit 3 text: "If the Task spec above lists" | `## Your output` is at :66, `## Task spec` at :88, so the Task spec comes *after* the new section | CONTRADICTED |
| The template marks optional parts with an explicit omit directive | edit 2: "omitted when the task has no `tests:`" | implementer-prompt.md:108 (`{if no upstream: omit this section entirely}`), :41 | VERIFIED (the convention exists; the plan's inserted text does not use it) |
| Case `round on "2" writes review_rounds: 3` was added in 76ed77d and is printed once | EU1 run, L811-815 | `git show 76ed77d -- tests/plan-state/plan-state.test.sh` adds tests/plan-state/plan-state.test.sh:775 inside `for q in '"2"' "'2'"`; `chk` prints `  PASS: <name>` (:11, :13) | VERIFIED |
| `.scratch/` is git-ignored | EU1 run | .gitignore:16 | VERIFIED |
| A `tests:` value on the key line is refused, and `plan-state tests` exits 2 on it | EU1 run writes `tests: [ ... ]` | plan L166-167, L192, L260 (criterion "inline tests value is refused"), L433 (step 6); spec L71-73. This is the plan's own design, not code; no code has landed | VERIFIED against the artifact |
| ok-absent means "the suite stopped early", not "the test was added with the task" | ok-absent criterion, L746-750 | spec L241-244 and step 6 (spec L228-231, plan step 6) | VERIFIED |

### Findings

- **DEFERRED** · The EU1 run writes the task's `tests:` in the inline form that the plan's own rule 16 refuses.
  - Artifact text: "whose running task declares `files: [skills/writing-dag-plans/plan-state, tests/plan-state/plan-state.test.sh]`, `tests: [tests/plan-state/plan-state.test.sh :: round on "2" writes review_rounds: 3]`" (L809-811; the B1 fix edited this line).
  - Evidence: plan L166-167 ("Any value on the `tests:` line itself (`tests: [a :: b]`, ...) is a violation"), L260 (a suite case asserts `tests: [t/a.sh :: x]` gives `tests must be a block list`), L433 (`plan-state tests` exits 2 on a task-level rule 16 failure); spec L71-73.
  - Concrete failure: an implementer who copies the declaration as written gets `verify-tests` exit 2 with `rule 16: ... tests must be a block list`, not "`ok`, exits 0". The bracket form here is shorthand, but nothing marks it so, and in the same document it is the one form the task's own dependency is built to refuse. The stderr line names the cause, so the implementer can recover. That is why this is not BLOCKING.
  - Resolution: write the entry in block form (`tests:` then `  - tests/plan-state/plan-state.test.sh :: round on "2" writes review_rounds: 3`), or say "a block-form `tests:` entry".

- **DEFERRED** · The new `## Named tests` section points at "the Task spec above", but the plan puts it above the Task spec.
  - Artifact text: "3. Inside the prompt template, a new section right before "## Your output"" and "If the Task spec above lists `Named tests:`". The criterion requires "the heading's line number is less than that of `^## Your output`".
  - Evidence: implementer-prompt.md:66 (`## Your output`) comes before :88 (`## Task spec`). The section therefore renders before the Task spec and its `Named tests:` list.
  - Concrete failure: the condition the section keys on (the B3 fix) points the wrong way. If the implementer reads "above" literally, the nearest `Named tests` above the sentence is the section's own heading, so a task with no `tests:` can look as if it has some. A task that has them can look as if it has none, and the implementer may skip the exact-name rule and use a fix round. An LLM reader will usually find the list anyway, so this is DEFERRED.
  - Resolution: say "If the Task spec below lists `Named tests:`" or "If the `## Task spec` section lists `Named tests:`".

- **DEFERRED** · "Omitted when the task has no `tests:`" exists only in plan prose. Neither the text to insert nor any criterion carries it.
  - Artifact text: "add a `Named tests:` rendering, omitted when the task has no `tests:`:" followed by a two-line block (`Named tests:` / `{for each entry in task.tests: "  - " + entry}`). The criterion pins only those two lines and their position.
  - Evidence: the controller learns what to omit only from directives in the template itself (implementer-prompt.md:108 `{if no upstream: omit this section entirely}`; :41). The inserted block has no such directive, and no criterion asks for one.
  - Concrete failure: as written, a literal implementation leaves the controller with nothing that says to drop the `Named tests:` line. Every task without `tests:` then renders an empty `Named tests:` header, which satisfies the `## Named tests` section's own condition ("If the Task spec ... lists `Named tests:`") with zero entries. It is mostly harmless (no entries means nothing to check), but the condition the B3 fix introduced no longer tells the two kinds of task apart.
  - Resolution: add an omit line to the inserted block (for example, `{if task has no tests: omit the two lines above}`) with a criterion for it, or say that an empty list means no named tests.

- **DEFERRED** · The EU1 wall-time trigger does not serve the purpose it states.
  - Artifact text: "If the run takes more than about 540 s, report DONE_WITH_CONCERNS, so that task-exec-verify's text ("about 85 s per run") can be amended by `/update`." (L819-820)
  - Evidence: task-exec-verify's text (L997) says "about 85 s per run here, and the check runs it twice". EMP-1 (prior findings) records about 246 s per suite run on this machine.
  - Concrete failure: a run of, say, 490 s (about 3x the 85 s claim) triggers no report under the rule as written, so "about 85 s per run" ships uncorrected, and the implementer cannot tell whether to follow the 540 s rule or its stated purpose. "About 540 s" is also soft at the boundary. This sits next to the accepted D-timing and is reported only because the threshold sentence is new in this diff.
  - Resolution: tie the trigger to its purpose. Report when the per-suite time is well above 85 s (amend the text), and separately when the total nears the 600 s Bash limit (a timeout risk). Or drop the "so that ..." clause.

- **DEFERRED** · In Context call 7, the inserted sentence leaves "that" in "The implementer reports that as DONE_WITH_CONCERNS" without a clear antecedent.
  - Artifact text: "... `verify-tests` never removes a worktree it did not create, because another `verify-tests` may be using it at the same time. The implementer reports that as DONE_WITH_CONCERNS ..." (L114-118)
  - Evidence: the trigger is stated precisely in task-verify-tests' EU2 criterion ("If the log is empty, report DONE_WITH_CONCERNS ... (Context, call 7)", L825-827). Implementers receive the task body, not the Context section (implementer-prompt.md:9-12, :18).
  - Concrete failure: none reaches an implementer. This is inert text incoherence.
  - Resolution: "If the probe shows KILL, the implementer reports DONE_WITH_CONCERNS ...".

### Checked, no finding
- Step 4's "once their directories are gone" accurately describes `git worktree prune` and does not ask `verify-tests` to delete anything. It agrees with call 7's "never removes a worktree it did not create".
- The ok-absent case (L746-750) now names a falsifiable cause (the suite stops early because a file the task creates is missing) and agrees with the spec's rationale (spec L241-244) and with step 6.
- The new case "trees: new case passing on old code is not-red" is falsifiable and separates the two readings of step 6. If the implementation reverts the test file, `y` is absent before and is labelled `ok-absent`, exit 0. If it keeps the file, `y` passes before and is labelled `not-red`, exit 1. "The total `0 ok, 1 failed`" fixes `tests:` to that one entry.
- The KILL case is falsifiable as reworded. It uses its own `TMPDIR`, deletes the leak explicitly, and then requires only the main tree in `git worktree list`. A stale registration (shown as prunable) stays listed unless the next run actually prunes.
- The EU1 run's expected label, "`ok` exactly (not `ok-absent`)", is unambiguous. The case is printed once per run (plan-state.test.sh:775 inside a two-value loop), and the claim that it was added in 76ed77d holds. "One-off run, not a suite case" resolves D-EU1-oneoff.
- task-implementer-prompt's edit 1 and edit 2 anchors exist (implementer-prompt.md:19, :94). The criteria fix placement exactly (`^Named tests:$` once, the next line given verbatim, both between `^## Task spec` and `^### Body`), and the nested backticks in edit 1's literal are resolved by the regex `tests:. entries, when present`.

### Out of lens
- "`verify-tests` never removes a worktree it did not create" (call 7, KILL case) has no case that would fail on a violation. An implementation that force-removes every non-main worktree still passes the KILL case (verifiability).
