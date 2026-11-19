## Lens: coherence (round 2, diff-scoped)
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (no AGENTS.md, no .claude/audit-charter.md). Downstream context: this plan is the only consumer of the spec, all 16 tasks pending, no code landed. Findings below are plan-internal, so "downstream already states it correctly" does not apply to them.

Probes: none executed. I read the plan, the round-2 diff, prior-findings, ground-truth, and `skills/executing-dag-plans/implementer-prompt.md`. I ran `rg`/`git show` read-only on `tests/plan-state/plan-state.test.sh` and commit `76ed77d`.

### Grounding table
| Assumption | Where in artifact | Verified at | Status |
|---|---|---|---|
| "The implementer MUST receive" frontmatter line is `implementer-prompt.md:19` | task-implementer-prompt, edit 1 | implementer-prompt.md:19 is "This task's frontmatter (id, depends_on, files)." | VERIFIED |
| `depends_on:` line sits in `## Task spec`, followed by `### Body` | task-implementer-prompt, edit 2 and criterion | implementer-prompt.md:88 (`## Task spec`), :94 (`depends_on:`), :96 (`### Body`) | VERIFIED |
| `## Your output` comes after the new section and the Task spec comes after it too | task-implementer-prompt, edit 3 | implementer-prompt.md:66 (`## Your output`), :88 (`## Task spec`): Task spec is BELOW Your output | CONTRADICTS the phrase "Task spec above" (finding 1) |
| `76ed77d` added `round on $q writes review_rounds: 3` | task-verify-tests EU1 | `git show 76ed77d -- tests/plan-state/plan-state.test.sh` adds the chk at the diff's line 32; the name is built from `$q` (suite line 775) | VERIFIED |
| `git worktree prune` keeps a registration whose directory exists | Context call 7, step 4, KILL criterion | not run; stated identically in all three places, so internally consistent | UNVERIFIED here (grounding lens owns it) |

### Findings

- **DEFERRED** · The new `## Named tests` text points at "the Task spec above", but the plan places that section before `## Your output`, which is above the Task spec, so the Task spec is below it.
  - Artifact text (task-implementer-prompt, Implementation edit 3): "If the Task spec above lists `Named tests:`, each entry is `<file> :: <case>`." The same edit places the section "right before "## Your output"". The acceptance criterion requires "the heading's line number is less than that of `^## Your output`".
  - Evidence: implementer-prompt.md:66 `## Your output`, :88 `## Task spec`. Edit 2 puts the `Named tests:` rendering inside `## Task spec`, which comes after the edit-3 section. The same section says "The RED-THEN-GREEN report below", which is correct. So only "above" is wrong.
  - Concrete failure: the dispatched implementer is told to look above for a list that is rendered below. A model reading the whole prompt will find it, so the failure is a confusing pointer, not wrong behaviour. Every acceptance criterion can still be met, so it is not blocking.
  - Resolution: author chooses: say "below" or "in the Task spec", or move the section after `### Body`. The `^## Your output` ordering criterion fixes the first option as the cheaper edit.

- **DEFERRED** · task-reviewer-prompts still describes `ok-absent` as a case "missing because the task had not built it yet". task-verify-tests now says the opposite: `ok-absent` must not come from a case added with the task.
  - Artifact text: task-reviewer-prompts: "judge whether the case was red for the right reason (missing because the task had not built it yet). If the suite broke before reaching the case for another reason, such as a missing fixture or a syntax error, that is an ISSUES finding." task-verify-tests (changed): "The absence must come from the suite stopping early, not from the test being added with the task: the before tree keeps the task's finished test file (step 6), so a case added with the task is still run there."
  - Evidence: step 6 keeps every `<file>` that is a `test` line at its finished content, so the named case is always present in the before tree. `ok-absent` is therefore reachable only when the suite stops before the case. The only worked example in the diff is "it exits at its first line when a file the task creates is missing". That is a suite breaking early over a missing file, and a reviewer could classify it as "a missing fixture".
  - Concrete failure: if "it" means the case, the reviewer text describes a state step 6 now makes impossible. If "it" means the missing file, the canonical `ok-absent` example is close to the reviewer's named wrong reason, so reviewers may flag ISSUES on a correct run. I could not settle which reading is intended, so the reviewer-prompts text is **undecidable as written**.
  - Resolution: author states, in the reviewer text, what "right reason" now means: the suite stops early because code the task creates is missing, versus a pre-existing fixture or a syntax error. task-verify-tail's `(before)` block text is compatible with either reading and needs no change.

- **DEFERRED** · Call 7's last sentence, "The implementer reports that as DONE_WITH_CONCERNS", has lost its antecedent.
  - Artifact text: "...until then they stay listed. `verify-tests` never removes a worktree it did not create, because another `verify-tests` may be using it at the same time. The implementer reports that as DONE_WITH_CONCERNS so the executor text can be amended by `/update`".
  - Evidence: before the diff, "that" followed the leaked-temporary-directory sentence. The insertion puts a rule about not removing foreign worktrees between them. The only DONE_WITH_CONCERNS trigger in task-verify-tests is EU2's "If the log is empty".
  - Concrete failure: low. A reader could take "that" as the never-removes rule, and no implementer behaviour hangs on the misreading.
  - Resolution: move the inserted sentence after the DONE_WITH_CONCERNS sentence, or name the antecedent ("the leak").

### Checked, no finding

Contracts the diff changed, and every task that produces, consumes, asserts against or documents each of them. The count is 16 tasks in all; the lists below are the ones I opened.

1. **KILL, prune and "never removes a worktree it did not create"** (Context call 7, step 4, KILL case). Compared against all of these: Context calls 5, 6, 7; task-verify-tests step 4, step 9, the cleanup/`on_signal` sketch (it removes only `$work/after` and `$work/before`, which matches the new rule), and the cases "trees: no worktree or temp dir left", "signals: TERM/INT/HUP mid-run", "second signal", "cleanup: failed removal" and the KILL case; the EU2 criterion; task-exec-verify's timeout and "counts as exit 2" text; task-verify-args (its early `mktemp -d` scratch is the same `$work`). All are consistent: the KILL case's own `TMPDIR` does not conflict with the "TMPDIR is empty" cases, because those use the test's own directory.

2. **"before tree keeps the task's finished test files" and the `ok-absent` / `not-red` semantics.** Compared: step 6 (rule and the closing sentence "finished tests and everyone else's work"); step 8 labels; criteria "absent before is ok-absent", "new case passing on old code is not-red", "before tree deletes a path new since base" (a non-test task file, so it agrees with step 6), "red then green", and "passing before is not-red"; the `mkrepo` sketch; EU1; task-verify-tail (label-to-block rules, spec example, "one file gives after then before"; its fixtures must now build `ok-absent` through an early-exiting suite, which is not a contradiction); task-implementer-prompt's "(with your finished test files)", which matches step 6; task-format's five labels (names only). The only mismatch is finding 2.

3. **EU1 run and timing.** Compared: EU1 ("a one-off run", 600000 ms timeout, 540 s threshold), call 4 (EUs become criteria on task-verify-tests), task-exec-verify ("about 85 s per run here", 600000 ms, "runs it twice"), the step 7 note "No timeout of its own", and task-verify-args' header. The 540 s threshold sits under the 600000 ms (600 s) timeout, and the quoted "about 85 s per run" is a verbatim substring of task-exec-verify's text. task-exec-verify does not depend on task-verify-tests, so the "amend by `/update`" route is the right one. The remaining timing gap (4m06s measured against 85 s) is the already-deferred D-timing. The example name `round on "2" counts to 3` in task-tests-field (line 161) and task-format (line 1200) is a syntax example only and is never claimed red-then-green, so it does not conflict with EU1's `writes review_rounds: 3` name.

4. **Implementer rendering of `tests:`.** Compared: task-implementer-prompt edits 1-3 and all five of its new criteria (the `tests:. entries, when present` regex matches the backtick; the `^Named tests:$` count is 1 because `## Named tests` has a `##` prefix and the sentence mention is mid-line; line numbers: list at :16-23, then `## Task spec` at :88, `### Body` at :96, which satisfies "both lie between"); task-exec-verify's re-dispatch with the check output (the Task-spec render carries over); task-reviewer-prompts; task-writer 3.6 and S17 and task-lens (they speak of the planner's YAML block, not the implementer's input); task-format and task-updater. No other task claims the implementer sees the YAML block. The only mismatch is finding 1.

5. **Structure.** The mermaid block has 16 nodes and 8 edges matching the `depends_on` lines of all 16 tasks (tests-field, base-sha, tests-cmd, verify-args, verify-tests, verify-tail, exec-dispatch, exec-verify, implementer-prompt, reviewer-prompts, format, s17, writer, updater, lens, repo-docs). The six `review_mode: split` tasks match Context call 3. The diff did not touch the diagram or the task list.

### Out of lens
- None.
