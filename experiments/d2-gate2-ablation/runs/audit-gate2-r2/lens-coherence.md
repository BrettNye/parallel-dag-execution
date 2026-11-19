## Lens: coherence
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (POSIX sh helpers, LF/.gitattributes, suite shape, plain-words skills). No .claude/audit-charter.md, no nested CLAUDE.md. No downstream artifacts beyond the plan itself (all 16 tasks pending, nothing landed since dc30ba0), so no finding below can be marked STALE or evaporate against a later statement.

### Grounding table
| Assumption | Where in artifact | Verified at | Status |
|---|---|---|---|
| Mermaid nodes = 16 tasks; 8 edges equal the `depends_on` lists | mermaid L10-33 vs task YAML (L143, 276, 384, 515, 632, 817, 909, 956, 1024, 1074, 1131, 1202, 1251, 1297, 1343, 1383) | plan text only | VERIFIED |
| Mermaid per-node `files:` equal each task's `files:` (verify-args "+2 more" = 3 files) | mermaid L10-25 | plan text only | VERIFIED |
| Six script tasks set `review_mode: split`; only `task-verify-tests` has `model_hint: opus` | Context call 3 | YAML L149, 282, 390, 522, 638-639, 823 | VERIFIED |
| `usage lists rules 1-5 and 7-15` exists in the suite | task-tests-cmd | tests/plan-state/plan-state.test.sh:543 | VERIFIED |
| `plan-state` header line 4 reads "validate rules 1-5 and 7-15, ..." | task-tests-cmd | skills/writing-dag-plans/plan-state:4 | VERIFIED |
| S1-S16 appears twice in writing SKILL.md, once in updating SKILL.md, once in plan-quality.md, and once as "S1–S16" in README.md | Context call 8; task-writer, task-updater, task-s17, task-repo-docs | writing SKILL.md:69,214; updating SKILL.md:25; plan-quality.md:116; README.md:11 | VERIFIED |
| `rules 7–15` appears once in updating SKILL.md; `7–15` appears twice in plan-format.md | task-updater, task-format | updating SKILL.md:86; plan-format.md:263,265 | VERIFIED |
| `76ed77d` exists and `76ed77d^` resolves | task-verify-tests, empirical unknown 1 | `git cat-file -t 76ed77d` printed `commit`; `git log -1 76ed77d^` printed 1757d4d | VERIFIED |
| `.scratch/` is git-ignored | task-verify-tests, unknown 1 | .gitignore:16 | VERIFIED |
| The suite has a case named `round on "2" counts to 3` | task-tests-field example, task-verify-tests unknown 1 | tests/plan-state/plan-state.test.sh:774 builds it from `round on $q counts to 3` in a loop; I did not trace `$q` | UNVERIFIABLE (the name depends on the loop's values) |

I probed nothing outside the repo and wrote nothing in the tree except this report. The `git cat-file` and `git log` calls were read-only.

### Findings

- **BLOCKING (reconciler may downgrade)** · A later task falsifies earlier suite assertions, and nothing at the earlier point of claim says so. `task-verify-tests` fixes "label lines and total only"; `task-verify-tail` adds `---` blocks to stdout.
  - Artifact text, task-verify-tests: "this task prints the label lines and the total line only", "Stdout is compared exactly", and the criterion "'trees: git stdout never reaches stdout': stdout of every run in the suite holds only label and total lines (no `HEAD is now at`, no `Preparing worktree`)".
  - Artifact text, task-verify-tail: "After the total line, `verify-tests` prints the tail of each run ... `ok-absent` ... gets a before block", and its last criterion: "`bash tests/verify-tests/verify-tests.test.sh` ends with `RESULT: N passed, 0 failed`".
  - Concrete failure: the earlier cases "trees: absent before is ok-absent", "trees: passing before is not-red" (exit 1, `0 ok, 1 failed`), "trees: failing after is not-green" and "trees: duplicate name is ambiguous" each produce an `ok-absent`, `not-red`, `not-green` or `ambiguous` entry. After task-verify-tail those runs print `--- <file> (...)` and `  | ` lines. An exact stdout comparison then fails, and "stdout holds only label and total lines" is false for every such run. The tail task's own criterion (suite ends `0 failed`) cannot be met unless the implementer rewrites earlier tasks' cases. The tail task never says to do that, and a reviewer comparing the diff to the task body may call it out of scope.
  - Resolution: the author must choose. Either task-verify-tests states that its stdout assertions apply to the label and total lines only, for example by filtering with `rg '^(ok|not|ambiguous|verify)'` as the tail task's own sketch does. Or task-verify-tail is told to update those earlier cases.

- **DEFERRED** · The plan-level rule 16 function's signature differs between task-tests-field and task-tests-cmd.
  - Artifact text, task-tests-field: "Put the task-level checks in one awk function that returns how many fail and prints the lines only when asked... Keep the plan-level checks in a second function for the same reason"; the sketch is `r16task(t, say)`, with `say` 0 or 1 calling `viol()`, and rule 16 items are "one line on stdout".
  - Artifact text, task-tests-cmd: `r16plan(0)` / `r16plan(2)  # 2: print the lines to stderr`, plus "Steps 5 and 6 call the two rule 16 functions `task-tests-field` wrote, not copies of them".
  - Concrete failure: task-tests-field never specifies a stderr mode, and its sketch has only a 0/1 flag with stdout output. task-tests-cmd needs a mode that task-tests-field did not build. The implementer must change the earlier task's function, and the plan says both that it is reused unchanged and that it takes a new argument value. The sketches are marked illustrative, which is why this is not BLOCKING.
  - Resolution: task-tests-field should say the function takes an output-target argument (none, stdout, stderr), or task-tests-cmd should say it extends the function.

- **DEFERRED** · The `verify-tests` header can break its own `usage()`, the defect call 10 fixes in `plan-state`.
  - Artifact text, task-verify-args sketch: `usage() { sed -n '3,5p' "$0" | ...}`. The same task says the header carries "one line per exit code" (the sketch uses two Exit lines for three codes), plus the "It never writes..." sentence.
  - Artifact text, task-verify-tests: "The script's header comment gains a line starting `# Untracked files:`" and "a line starting `# Bash tool timeout:`".
  - Concrete failure: a fixed 3,5 range is only correct while the header's first three lines stay the same. The later task adds header lines with no stated position. Call 10 names this exact fragility as the reason for the `sed -n '3,/^# Exit:/p'` fix, and the plan does not apply it to the new script. The header also never gains the "cleanup failed" exit-2 reason from call 5.
  - Resolution: pin where the added header lines go, or use an address range ending at the `Exit:` block in `verify-tests` too. Add the cleanup-failed reason to the exit-2 line.

- **DEFERRED** · task-verify-tests' sketch contradicts its own prose and Context call 5 on cleanup.
  - Artifact text, task-verify-tests step 9: "Remove both worktrees ... and the temporary directory, on success, on failure, and from the trap." Call 5: "If removing a worktree or the temporary directory fails, on any path, `verify-tests` prints `verify-tests: <id>: cleanup failed` on stderr and exits 2".
  - Evidence: the sketch's early exits (`not in a git repository`, `cannot read HEAD`, `is not a commit`) do not call `cleanup` or `rm -rf "$work"`, although task-verify-args already created `$work` with `mktemp -d` and its exits do remove it. `cleanup()` returns non-zero but no line prints `cleanup failed`, and `on_signal` discards the return value.
  - Concrete failure: if an implementer follows the sketch literally, those three early exits leak the temporary directory and no path prints `cleanup failed`. The criteria cover the cleanup-failed case only through a test hook. Sketches are illustrative, so this is a trap for the implementer rather than an accepted-criterion conflict.
  - Resolution: the sketch should show where `cleanup failed` is printed and call `cleanup` or `rm -rf "$work"` before the early exits.

- **DEFERRED** · task-verify-tests refers to criteria by position, and the count is wrong.
  - Artifact text: "This task also carries the empirical unknowns from the spec's Audit record (see the last three criteria)."
  - Evidence: the three (unknown 1, unknown 2, D1) are followed by a fourth bullet, the final `RESULT: N passed` criterion, so the literal last three bullets are unknown 2, D1 and RESULT.
  - Concrete failure: a reader counts the wrong three and skips unknown 1.
  - Resolution: name them ("Empirical unknown 1 and 2, and D1").

- **DEFERRED** · "the four cases above" in task-verify-args' dash criterion is ambiguous.
  - Artifact text: "'args: runs under dash': ... the four cases above give the same exit codes".
  - Evidence: the four preceding bullets hold five named cases ("args: no arguments is usage", "args: plan-state error is relayed", "args: unreadable plan is relayed", "args: no named tests exits 0", "args: no base_sha exits 2").
  - Concrete failure: an implementer may run four of the five under dash, and a reviewer cannot tell which.
  - Resolution: say "the five cases above" or list them.

- **DEFERRED** · task-verify-tests' unknown 1 criterion runs a roughly 170 s check, but its text carries no timeout instruction.
  - Artifact text, task-exec-verify: "a plan-state suite takes about 85 s per run here, and the check runs it twice. The default 120 s limit is too short... explicit `timeout` of 600000 ms."
  - Artifact text, task-verify-tests: the unknown 1 criterion has `verify-tests` run on this repository with `tests/plan-state/plan-state.test.sh :: round on "2" counts to 3`, which runs that suite twice. It gives no timeout guidance.
  - Concrete failure: an implementer running the criterion through the Bash tool with the default limit will see it time out, though the plan already knows this elsewhere.
  - Resolution: repeat the 600000 ms instruction in the criterion.

- **DEFERRED** · Context call 8 names three targets by a shorthand that does not match the declared paths.
  - Artifact text: "`writing-dag-plans/SKILL.md`, `updating-dag-plans/SKILL.md`, ... `auditing-artifacts/SKILL.md`" (prose L119-121).
  - Evidence: the declared-paths table shows these three ABSENT because the `skills/` prefix is missing. The `files:` of task-writer, task-updater and the task-lens line use the full `skills/...` paths, and nothing is wrong there.
  - Concrete failure: none for execution. A reader grepping the plan for these paths finds no matching `files:` entry.
  - Resolution: add the `skills/` prefix.

### Checked, no finding
Central contracts enumerated and compared task by task.

1. **Dependency graph (mermaid vs YAML).** All 16 tasks and all 8 edges match: tests-field→base-sha, base-sha→tests-cmd, tests-cmd→verify-args, verify-args→verify-tests, verify-tests→verify-tail, exec-dispatch→exec-verify, verify-args→exec-verify, verify-args→repo-docs. The nine roots (tests-field, exec-dispatch, implementer-prompt, reviewer-prompts, format, s17, writer, updater, lens) have `depends_on: []`. No task id in prose is undefined: `task-exec-dispatch`, `task-verify-args`, `task-verify-tests` and `task-verify-tail` are all referenced correctly. The "Shape" prose (three plan-state tasks chain, three verify-tests tasks chain, two wait on verify-tests) matches.
2. **The `tests:` entry grammar** (`<file> :: <case>`, first ` :: `, `./` removal, raw entry kept literally, block form only). 11 tasks produce, consume or document it, and I compared all of them: task-tests-field, task-base-sha, task-tests-cmd, task-verify-args, task-verify-tests, task-implementer-prompt, task-format, task-writer, task-updater, task-lens, task-s17. They agree, including "block form only" and "the name is unique in its file".
3. **The `plan-state tests` record format** (`base`/`command`/`pass`/`fail`/`file`/`test` with a tab). Producer task-tests-cmd and consumer task-verify-args agree (`IFS= read -r`, `base -`, split at the tab). task-verify-tests relies on the `file` lines for the step 6 revert and on the `test` lines for the run, consistent with the format.
4. **The five labels** (`ambiguous`, `not-green`, `not-red`, `ok-absent`, `ok`) and the "ok / failed" counting. All 6 tasks that name them agree: task-verify-tests, task-verify-tail, task-format, task-reviewer-prompts (`ok`, `ok-absent`, `(before)` tail), task-implementer-prompt, task-repo-docs. Header text `--- <file> (before)` / `(after)` is identical between the tail task, the spec example and the reviewer prompt. Precedence (`not-green` wins over `not-red`) agrees between verify-tests and verify-tail.
5. **The `{verify_tests_output}` placeholder** appears in the Context names list, task-exec-verify (substitute into the reviewer prompt on exit 0) and task-reviewer-prompts (both templates). It is spelled identically in all three. The reviewer-prompts criterion says the quality prompt is untouched; that matches the `files:` list.
6. **The `verify-tests` path and the `plan-state` relative path.** `skills/executing-dag-plans/verify-tests` and `../writing-dag-plans/plan-state` appear identically in Context, task-verify-args, task-exec-verify, task-repo-docs and the mermaid labels.
7. **`base_sha` semantics** (written on first `running`, kept through resume, refused with exit 2 only for a task with tests, rule 17 is 7-40 lowercase hex). task-base-sha, task-exec-dispatch ("Mark running first"), task-verify-args (`no base_sha` exit 2), task-format and task-updater agree. The error text `cannot read HEAD for base_sha` is identical in task-base-sha and task-exec-dispatch.
8. **Rule and heuristic range references** (Context call 8). The edits specified match the real occurrences: writing SKILL.md 2×S1-S16, updating SKILL.md 1×S1-S16 and 1×`rules 7–15`, plan-quality.md 1×, README.md 1×, plan-format.md 2×`7–15`, and the usage header and assertion in plan-state. The two "has already passed H1–H11 and S1–S16" passages (auditing-artifacts SKILL.md:223, commands/audit-plan.md:19) are correctly left alone. task-tests-cmd's header text (`1-5 and 7-17`, ASCII hyphen) matches its own renamed assertion.
9. **Call 1 (this plan uses no `tests:` fields).** No task YAML carries a `tests:` key; the `tests:` snippets in the task bodies are fixtures or documentation.
10. **Call 3 vs task YAML** and **Call 4 (three unknowns become criteria on task-verify-tests).** Both hold, apart from the positional wording noted above.
11. **Files vs bodies.** Each task's body edits only paths in its own `files:`. task-verify-args owns `.gitattributes` as the Shape paragraph says. `quality-reviewer-prompt.md` is correctly excluded from task-reviewer-prompts.
12. **Executor SKILL.md ordering.** task-exec-dispatch (step 4 paragraph) and task-exec-verify (diagrams, round-cap sentence, table row, "Named-test check" paragraph) edit disjoint places in the same file and are ordered by `depends_on`. task-exec-verify's last criterion protects the earlier task's paragraph.

### Out of lens
- Whether task-verify-tests' "ok-absent" criterion fixture can occur while the task's finished test file is kept in the before tree (step 6) is a spec-fidelity question for `coverage` or `feasibility`.
- The plan's "about 85 s per run" claim for the plan-state suite is unmeasured here; an empirical check belongs to whichever lens owns timing assumptions.
