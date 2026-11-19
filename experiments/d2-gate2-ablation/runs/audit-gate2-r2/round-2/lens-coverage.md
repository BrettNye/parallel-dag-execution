## Lens: coverage
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (no AGENTS.md, no .claude/audit-charter.md). Scope: round-2 diff only (Context call 7; task-verify-tests step 4, ok-absent, the new not-red case, KILL case, EU1 run; task-implementer-prompt Implementation and criteria), checked against the frozen spec and against prior-findings.md. Downstream: this plan is the only consumer, nothing landed (per dispatch). No probes run; nothing written in the tree except this report.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| Spec step 4 asks for `git worktree prune` "to clear registrations left by an earlier run that was killed" | Task verify-tests step 4 (L653-655) | spec:221-222 | VERIFIED. The added "once their directories are gone" describes git, not new behaviour |
| Spec step 6 keeps the task's test files at HEAD in the before tree | new case "trees: new case passing on old code is not-red" (L752-756) | spec:228-231 | VERIFIED. The new case pins it |
| Spec's ok-absent means "absent in the before tree", for example a suite that stops early | reworded "trees: absent before is ok-absent" (L746-750) | spec:241-244 | VERIFIED. The rewording matches the spec's own example |
| Spec requires the implementer be told the named-test rules "when the task has tests:" | task-implementer-prompt Implementation (L1058-1086) | spec:338-341 | VERIFIED as owned; see the DEFERRED finding on the "when" half |
| Implementer sees only the rendered template, not the YAML block | task-implementer-prompt L1058-1059 | implementer-prompt.md:16-23, 88-98 | VERIFIED |
| "MUST receive" frontmatter line is :19; `## Task spec`/`depends_on:`/`### Body` exist | edits 1-2 (L1061-1068) | implementer-prompt.md:19, :88, :94, :96 | VERIFIED |
| SKILL.md builds the implementer prompt from the template only, so the template is the one surface for rendering | (implicit in edit 2) | SKILL.md:24, :35, :136 (delegates to `./implementer-prompt.md`; no field list of its own) | VERIFIED |
| EU1 case `round on "2" writes review_rounds: 3` exists and was added in 76ed77d | EU1 bullet (L810-815) | tests/plan-state/plan-state.test.sh:771-775 (loop over `'"2"'`); absent from `git show 76ed77d^:tests/plan-state/plan-state.test.sh` (rg `round on` finds only :490-491, :519) | VERIFIED (grounding lens owns the detail) |

### Findings

- **DEFERRED** · The implementer-prompt rendering covers the content but only half-pins the spec's "when the task has tests:". The omission is stated in prose but missing from the snippet and the criteria.
  - Artifact text: "add a `Named tests:` rendering, omitted when the task has no `tests:`:" followed by the snippet "Named tests:\n{for each entry in task.tests: \"  - \" + entry}". The criterion checks only "`rg -c '^Named tests:$'` prints `1`, the next line is `{for each entry in task.tests: ...}`".
  - Evidence: the template states omission explicitly where it wants it, e.g. `{if no upstream: omit this section entirely}` at implementer-prompt.md:108. The plan's snippet has no such directive. None of the task-implementer-prompt criteria (L1093-1116) checks for one.
  - Concrete failure: suppose the implementer copies the snippet verbatim. The controller then renders an empty `Named tests:` header for every task. The new `## Named tests` section ("If the Task spec above lists `Named tests:`") then applies to tasks without `tests:` too. With zero entries the rules are vacuous, so the damage is a misleading prompt rather than wrong behaviour. Spec:338 ("When the task has tests:") and spec:375 ("Plans without tests: behave exactly as today") are not pinned.
  - Resolution: add `{if task has no tests: omit these two lines}` to the snippet, and a criterion that greps for it.

No BLOCKING findings. The four round-1 blocking fixes cover the spec requirements they target and add no behaviour the spec did not ask for:
- B1/B4: EU1 now names a case that is red at `76ed77d^`, and a new suite case pins spec step 6's keep-the-test-files rule.
- B2: the KILL case still pins spec step 4's prune. `git worktree list` lists a registration whose directory is gone until prune runs, so a missing prune still fails the case after the test deletes the leak.
- B3: entries are rendered into `## Task spec`, which is the only surface the implementer sees.

### Checked, no finding
- Context call 7's "`verify-tests` never removes a worktree it did not create" is a restriction, not new behaviour. It is consistent with the spec's "It never: ... touches the shared working tree" (spec:300) and the concurrency anti-goal (spec:38-39). It is not over-build.
- Step 4's "once their directories are gone" changes no requirement (spec:221-222).
- The reworded ok-absent case still owns spec 8.4 (spec:241-244). Its "suite stops early" framing is the spec's own example.
- The new not-red case adds no behaviour. It is the first owner of spec 6's "So the before tree has the task's finished tests" (spec:230-231) as a test. Before this diff that half was stated but not pinned.
- The KILL case's own `TMPDIR` and its deletion of the leak are test mechanics. They do not change what spec step 9 requires. The spec has no KILL requirement (spec:246-247 names INT, TERM, HUP).
- The EU1 run is now explicitly a one-off, gets an explicit timeout, records wall time, and reports DONE_WITH_CONCERNS above about 540 s. All of this serves the spec's Audit-record empirical unknown (spec:396-397) and the plan's open EMP-1. The shipped wall-time line falls under the already-deferred D-timing.
- task-implementer-prompt edits 1-3 together cover every clause of spec:338-341: exact name, fail before and pass after, checked by a script from committed work, commit before reporting, RED-THEN-GREEN kept. The new criteria (L1101-1108) pin the receive-list line and the rendering position. Nothing beyond the spec is added: rendering the entries is necessary for the spec's "say the following" to reach the implementer, and spec:382 leaves the prompt wording to the builder.
- SKILL.md has no field list of its own for the implementer prompt (SKILL.md:24, :35, :136), so there is no second surface for the rendering that lacks an owner.

### Out of lens
- `agents/dag-implementer.md:12` lists what the implementer receives as "`id`, `depends_on`, `files`, body, acceptance criteria" and no task updates it to include named tests. This is the implementer counterpart of the deferred D-agents (coherence).
