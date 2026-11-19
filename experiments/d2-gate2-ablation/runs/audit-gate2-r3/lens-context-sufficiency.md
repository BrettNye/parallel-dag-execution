## Lens: context-sufficiency
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (no .claude/audit-charter.md, no nested CLAUDE.md/AGENTS.md, no docs it points to)

Downstream context: the plan under audit is the only consumer of the spec. All 16 tasks are `pending`, and no commits have landed since dc30ba0. No finding below goes away because of a downstream artifact.

Probe (outside the repo): I wrote `git show '76ed77d^:skills/writing-dag-plans/plan-state'` to a `mktemp -d` scratch directory under /tmp. There I rebuilt the suite's `clean_plan` and `mkrr` fixture with `review_rounds: "2"` and ran `sh ps-old round r31.md task-a`. It printed `rc:out=[0:3]` and left `review_rounds: "2"` unchanged. This result is used only in the Out of lens section. Nothing in the repository was written except this report.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| plan-state parser has `yamlline`, `ylist`, `stripc`, `trim`, `unq`, `fil[t,j]`/`nf[t]`, `viol`, `err`, `fm`/`fmset` | task-tests-field sketch, L201-227; task-tests-cmd sketch, L447-462 | skills/writing-dag-plans/plan-state:31-61, :338 | VERIFIED |
| `files:` items are normalised (unquoted, `./` stripped) | task-tests-field L186; task-tests-cmd L412-414 | plan-state:39-44 | VERIFIED |
| `round` inserts `review_rounds:` after `status:`, keeping indentation and CR | task-base-sha L304-305 | plan-state:374-375 | VERIFIED |
| top-of-script `[ "$#" -ge 2 ]` check, then the `cannot read` check | task-tests-cmd L421-424 | plan-state:23-25 | VERIFIED |
| `usage()` is `sed -n '3,12p'`; the header's `check` line says `rules 1-5 and 7-15` | task-tests-cmd L437-442 | plan-state:4, :22 | VERIFIED |
| suite helpers `ok bad chk has hasnt`, `ALTSH`, `clean_plan` (task-a done, task-c holds `tests/hook.test.sh`), the case `usage lists rules 1-5 and 7-15` | task-tests-field L240; task-base-sha L347; task-verify-args L553-557 | tests/plan-state/plan-state.test.sh:9-15, :24-77, :543 | VERIFIED |
| `.gitattributes` has an "Extensionless shell script" block | task-verify-args L527 | .gitattributes:26-30 | VERIFIED |
| executor step 4 holds `Mark it with ...running.` and starts with `**Dispatch in parallel:**` | task-exec-dispatch L924-926 | skills/executing-dag-plans/SKILL.md:35 | VERIFIED (but see finding 3) |
| two review-chain diagrams with `implementer DONE`; `**Reading a verdict.**`; Review-round cap first sentence; ISSUES table row | task-exec-verify L973-994 | SKILL.md:53-68, :70, :72, :90 | VERIFIED |
| `## Your output`, `RED-THEN-GREEN (required` in the implementer prompt | task-implementer-prompt L1038, L1066 | implementer-prompt.md:66, :73 | VERIFIED |
| the implementer prompt carries the task's `tests:` list | task-implementer-prompt L1043 ("If your task's YAML block has a `tests:` list") | implementer-prompt.md:18-19, :88-98 | CONTRADICTED |
| reviewer "MUST receive" list and sentence; `## Implementation under review` in both templates | task-reviewer-prompts L1092-1095 | spec-reviewer-prompt.md:14-18, :78; merged-reviewer-prompt.md:8, :80 | VERIFIED |
| plan-format anchors: `default_quality_reviewer_hint`, `review_rounds`, `### Mixing implementers`, rule 15, `#7–#15`, `enforces rules 1–5 and 7–15` (the only `7–15` hits) | task-format L1147-1176 | skills/writing-dag-plans/plan-format.md:32, :109, :112, :261, :263, :265 | VERIFIED |
| `### S16`, `## Detection algorithm`, and the only `S1-S16` | task-s17 L1217-1228 | plan-quality.md:104, :112, :116 | VERIFIED |
| step 3.5, step 4, and two `S1-S16` hits in the writer SKILL | task-writer L1265-1274 | writing-dag-plans/SKILL.md:69, :126, :144, :214 | VERIFIED |
| `review_rounds:` paragraph, `S1-S16`, `rules 7–15` in the updater | task-updater L1312-1320 | updating-dag-plans/SKILL.md:25, :59, :86 | VERIFIED |
| `## \`verifiability\`` and `**No observable check at all**` | task-lens L1357 | auditing-artifacts/lenses-plan.md:179, :186 | VERIFIED |
| `.scratch/` is ignored; commit `76ed77d` exists; the case `round on "2" counts to 3` exists | task-verify-tests L792-796 | .gitignore:16 (`git check-ignore -v`); `git log 76ed77d`; plan-state.test.sh:771-774 | VERIFIED (but see Out of lens) |

### Findings

- **BLOCKING** · The new `## Named tests` section tells the implementer to read a `tests:` list it is never given. No task adds `tests:` to what the implementer receives.
  - Artifact text (task-implementer-prompt, L1043): "If your task's YAML block has a `tests:` list, each entry is `<file> :: <case>`. For each entry: - the case must exist in `<file>` with exactly that name ..."
  - Evidence: implementer-prompt.md:18 says the body is "everything after the YAML block". implementer-prompt.md:19 limits the frontmatter passed to "(id, depends_on, files)". The template's `## Task spec` (:88-98) renders only `{task.id}`, `task.files`, `task.depends_on` and `{task.body}`.
    - First search: `rg 'MUST receive|task\.tests|\{task\.|Task spec|frontmatter \(id'` over the plan. It finds only task-reviewer-prompts' edits to the two reviewer prompts (L1092-1093, L1120).
    - Second search: I read every task whose `files:` include implementer-prompt.md or the executor SKILL.md (task-implementer-prompt, task-exec-dispatch, task-exec-verify). None adds `tests:` to the implementer's context list or template.
  - Concrete failure: in any later plan that uses `tests:`, the implementer sees the rules for named tests but not the entries. It has to guess which acceptance criteria are named tests and what their exact case strings are. A wrong guess means the case is absent in the after tree, so `not-green` and `verify-tests` exit 1. That costs a fix round from the cap of 3. Only then does the `verify-tests` output reveal the names, through the re-dispatch issue list. The spec's aim that the implementer is told what the script will check is not delivered. A related gap: the re-dispatch template (implementer-prompt.md:135) frames every issue list as "the {spec / quality} reviewer found issues". task-exec-verify (L979) sends the `verify-tests` output through that same path, and no task gives it a matching framing.
  - Resolution: in task-implementer-prompt, add two edits and an acceptance criterion for each:
    - add "this task's `tests:` entries, if any" to the MUST-receive list at implementer-prompt.md:19;
    - render them in the template's `## Task spec`, for example `Named tests: {for each entry in task.tests: "  - " + entry}`, omitted when there are none.

    Optionally also add a re-dispatch variant line for a failed `verify-tests`. All of these are within the task's existing `files:`.

- **DEFERRED** · task-format must document the five labels and the matching rule, but its body gives only the label names and a topic outline. The meanings come from a pointer.
  - Artifact text (L1140-1141, L1163-1168): "Spec: ... with the field and rule text from "The plan format"." and "the matching rule (pass line, fail line with optional ` (` detail, passed/failed/absent/ambiguous); ... and the five labels `ok`, `ok-absent`, `not-red`, `not-green`, `ambiguous`."
  - Evidence: the plan's own label definitions and their order ("the first that applies wins") are inlined only in task-verify-tests (L679-684). The output-line normalisation is also only there (L672-673). task-format is a root task (`depends_on: []`), so it sees neither that body nor the built script.
  - Concrete failure: the implementer has to invent what `ok-absent` and `not-red` mean and which label wins. The merged reviewer checks only that the five names appear (AC L1194-1195), so a wrong definition is approved. plan-format.md is the reference planners are told to read. Nothing executes from it, so this is DEFERRED.
  - Resolution: copy task-verify-tests' L672-684 (line normalisation, the four run states, and the label order) into task-format's item 3.

- **DEFERRED** · task-exec-dispatch's placement instruction conflicts with its own acceptance criterion. The only layout that satisfies both is never described.
  - Artifact text (L925-926): "put this paragraph at the start of step 4's text, before "**Dispatch in parallel:**" is described". AC (L940-942): "`rg -c '^\s*\*\*Mark running first\.\*\*'` prints `1`, and the paragraph sits inside step 4 (after the line starting `4. ` and before the line starting `5. `)".
  - Evidence: step 4 is a single list line that begins `4. **Dispatch in parallel:**` (SKILL.md:35). Putting the paragraph at the start of that line breaks the `^\s*\*\*Mark` regex and the "after the line starting `4. `" condition. Putting it after line 35 places it after Dispatch is described. SKILL.md:101 and :104 are also lines starting `4. ` and `5. `, which makes the AC's anchors ambiguous.
  - Concrete failure: the implementer must guess a restructure of step 4, such as a new short `4.` lead line. The obvious placements fail one of the two requirements, which likely costs a fix round. The behaviour is unaffected, because the paragraph itself says "before ... never after".
  - Resolution: state the layout. For example: "step 4's first line becomes `4. **Mark running, then dispatch.**`; the paragraph follows as an indented continuation; `**Dispatch in parallel:**` starts the next indented paragraph". Or relax the AC to allow `^4\. \*\*Mark running first`.

- **DEFERRED** · task-repo-docs says to name the helper "where the repo lists its helpers" but lists only two edits. The README's helper-suite list goes stale.
  - Artifact text (L1391): "Name the new helper where the repo lists its helpers and features."
  - Evidence: README.md:120 says "The four helper scripts have real test suites". README.md:122-127 lists one `bash tests/...` command per suite. README.md:129-133 lists plan-state's subcommands. The task's Implementation (L1398-1407) and ACs (L1417-1421) cover none of these.
  - Concrete failure: after the plan runs, the README says "four" helpers, omits the `tests/verify-tests/verify-tests.test.sh` command, and does not mention `plan-state tests`. The implementer must guess whether these are in scope, and the reviewer has no criterion that covers them.
  - Resolution: add "README.md:120 'four' becomes 'five'; add `bash tests/verify-tests/verify-tests.test.sh`; add `tests` to the plan-state paragraph", with an `rg` criterion. CLAUDE.md's "Running the tests" loop (CLAUDE.md:28) already globs `tests/*/*.test.sh` and needs no change.

- **DEFERRED** · task-verify-tests is too large to implement and review in one pass.
  - Artifact text (L629-812): steps 4-9, about 20 named cases (three signal variants, a second signal, KILL, failed cleanup with a test-only hook the implementer must design), two empirical probes, a manual run on this repository, and two header-comment findings.
  - Evidence: the plan's Context call 3 (L98-99) acknowledges the load by setting `model_hint: opus`. The chain is serial either way (L29-30), so splitting it loses no parallelism.
  - Concrete failure: none that is certain. One implementer turn and one split review have to hold worktree building, classification, trap semantics and probe reporting together, and a single fix round reopens all of it.
  - Resolution (optional): split it into task-verify-trees (steps 4-9 without signal handling, cases L742-775) and task-verify-signals (the trap, second signal, KILL, failed cleanup, both empirical unknowns), with task-verify-tail after either.

- **DEFERRED** · task-verify-args says "the four cases above" where five case names are quoted.
  - Artifact text (L618-619): "when `dash` is installed, the four cases above give the same exit codes under `dash "$SCRIPT"`".
  - Evidence: L607-617 quote five names: "args: no arguments is usage", "args: plan-state error is relayed", "args: unreadable plan is relayed", "args: no named tests exits 0", "args: no base_sha exits 2".
  - Concrete failure: the implementer has to guess which case is left out of the dash re-run. Any choice passes review, so the impact is negligible.
  - Resolution: name the cases, or say "the five cases above".

### Checked, no finding
- Every task restates the spec text it needs, apart from the gaps above: rule 16 and 17 messages, the `set ... running` order, the `plan-state tests` output and its exit-2 order, verify-tests steps 1-9, output, exit codes and tails, the executor paragraph, the reviewer section, and the S17 row. The `Spec: "<section>"` lines are provenance tags, not pointers that replace content. The exception is task-format, above.
- The Context pointers inside task bodies ("Context, calls 5 and 6" at L694, "call 7" at L807, "calls 8 and 9" at L1394, "Deferred gate-1 finding D1" at L808) each have their content inlined nearby. None leaves the implementer guessing.
- Existing-code anchors that sketches and Implementation sections rely on resolve (see the grounding table). Replacement strings match the current text, and the `rg` "prints nothing" criteria in task-format, task-s17, task-writer and task-updater cover every current occurrence of the old string.
- Dependencies within the chains: task-tests-cmd reuses task-tests-field's functions through the shared file, which it reads. task-verify-tests and task-verify-tail each depend directly on the task whose script they extend. task-exec-verify depends on task-exec-dispatch (same file) and restates the `{verify_tests_output}` name, so it does not need to see task-reviewer-prompts.
- `files:` scope fits the work for every task except as noted. The `.gitattributes` edit is owned by task-verify-args. The S1-S16 sites the plan leaves alone (auditing-artifacts/SKILL.md, commands/audit-plan.md) are deliberately out of scope (Context call 8).
- Parallelism: the doc and prompt tasks are roots. The serial edges (task-verify-args → task-exec-verify, task-verify-args → task-repo-docs) are justified: those tasks cite a path that task-verify-args creates, which preflight's P2 would otherwise flag. No chain could be split further.

### Out of lens
- task-verify-tests' empirical-unknown-1 expectation (L792-796, "`verify-tests` prints `ok` for that entry and exits 0") is wrong. At `76ed77d^`, `round` printed 3 and exited 0 on a quoted count (commit message of 76ed77d; scratch probe printed `rc:out=[0:3]`). So `round on "2" counts to 3` passes before and would be labelled `not-red` with exit 1. The case that fails before is `round on "2" writes review_rounds: 3` (plan-state.test.sh:775). Owned by grounding or verifiability.
