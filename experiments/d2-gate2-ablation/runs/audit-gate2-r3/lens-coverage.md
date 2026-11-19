## Lens: coverage
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (no .claude/audit-charter.md, no nested CLAUDE.md/AGENTS.md, no convention docs it points to). Parent spec read in full. Downstream context: the plan under audit is the only consumer; all 16 tasks pending; nothing has landed since dc30ba0, so nothing below can be STALE.

No probes run; nothing executed outside read-only `rg`/`sed`/`wc` over the tree.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| Executor step 4 holds the after-dispatch "Mark it with `plan-state set <plan> <id> running`." sentence the task removes | task-exec-dispatch, Implementation | skills/executing-dag-plans/SKILL.md:35 | VERIFIED |
| Only two review modes exist (split, merged), so "both diagrams" covers every review path | task-exec-verify step 2 | SKILL.md:39 (`{merged, split}`), SKILL.md:52-68 | VERIFIED |
| Review-round cap paragraph and status table ISSUES row exist | task-exec-verify steps 3-4 | SKILL.md:72, SKILL.md:90 | VERIFIED |
| Spec and merged reviewer prompts have "MUST receive" list/sentence and "## Implementation under review" | task-reviewer-prompts | spec-reviewer-prompt.md:14-18, :78; merged-reviewer-prompt.md:8, :80 | VERIFIED |
| Quality reviewer has no verify-tests placeholder today | task-reviewer-prompts AC 4 | quality-reviewer-prompt.md (rg `\{[a-z_]+\}` shows none) | VERIFIED |
| Implementer prompt has "## Your output" and a "RED-THEN-GREEN (required" field | task-implementer-prompt | implementer-prompt.md:66, :73 | VERIFIED |
| plan-state usage() is a fixed `sed -n '3,12p'`; check line reads "rules 1-5 and 7-15" | task-tests-cmd | skills/writing-dag-plans/plan-state:4, :22 | VERIFIED |
| Suite case "usage lists rules 1-5 and 7-15" exists | task-tests-cmd | tests/plan-state/plan-state.test.sh:543 | VERIFIED |
| `round` already inserts a line with the status line's indent and CR | task-base-sha step 5 | plan-state:372-375 | VERIFIED |
| Every "S1-S16"/"S1–S16" enumeration is either owned or deliberately kept (Context call 8) | Context call 8 | README.md:11 (task-repo-docs); writing-dag-plans/SKILL.md:69, :214 (task-writer); plan-quality.md:116 (task-s17); updating-dag-plans/SKILL.md:25 (task-updater); commands/audit-plan.md:19 and auditing-artifacts/SKILL.md:223 (kept by call 8). Two strategies: `rg 'S1.S16'` over the tree excluding docs/, and `rg 'S16\|soft heuristics'` over skills/ commands/ agents/ README.md | VERIFIED |
| Every "7–15"/"7-15" rule-range reference is owned | task-format, task-updater, task-tests-cmd | plan-format.md:263, :265 (task-format); updating-dag-plans/SKILL.md:86 (task-updater); plan-state:4 and plan-state.test.sh:543 (task-tests-cmd). Same two rg sweeps | VERIFIED |
| Doc anchors the doc tasks insert after exist | task-format, task-s17, task-writer, task-updater, task-lens | plan-format.md:112 (Mixing implementers), :261 (rule 15); plan-quality.md:104 (S16), :112 (Detection algorithm); writing-dag-plans/SKILL.md:66, :126 (3.5), :144 (4.), :212 (7.); updating-dag-plans/SKILL.md:22, :59; lenses-plan.md:179, :186; .gitattributes:26 | VERIFIED |
| Reviewer/implementer agent definitions carry no test-running instruction that would contradict "do not re-run" | (spec: The prompts) | agents/dag-spec-reviewer.md, agents/dag-merged-reviewer.md (rg `red\|run \|mutation\|test`: no such instruction) | VERIFIED |
| A `tests:` block list does not leak into resolve-declared-paths' `files:` parsing | (spec Constraint: plans without tests: unchanged) | resolve-declared-paths:106-113 (any non-`- ` line ends the files list) | VERIFIED |

### Requirement → task matrix

| # | Spec requirement (section) | Owning task(s) | Coverage |
|---|---|---|---|
| 1 | `tests:` block form only; value on key line is rule 16; trailing comment on key line is not a value (Task fields) | task-tests-field | full |
| 2 | Raw entry: literal, trailing CR/space removed, no comment/quote/comma handling (Task fields) | task-tests-field | full |
| 3 | Split at first ` :: `; `<file>` trimmed and every leading `./` removed; `<case>` trimmed (Task fields) | task-tests-field | full |
| 4 | Sameness by normalised pair; all output uses the normalised pair | task-tests-field (repeat), task-tests-cmd (`test` lines), task-verify-tests (label lines) | full |
| 5 | Case unique in its file: verify-tests reports `ambiguous`; writing-dag-plans tells authors to rename | task-verify-tests, task-writer (also task-implementer-prompt, task-format) | full, both surfaces |
| 6 | `base_sha:` written first time running, kept through resume reset and next running | task-base-sha | full |
| 7 | Plan-level `test_command`, `test_pass_prefix`, `test_fail_prefix`, defaults, comment-stripped then unquoted | task-tests-field (parse), task-tests-cmd (defaults applied) | full |
| 8 | `{file}` → single-quoted path; `sh -c` from tree root; stdin `/dev/null`; no own timeout | task-verify-tests step 7 | full |
| 9 | Matching output lines rules 1-5 (normalise; pass line; fail line incl. ` (`; passed/failed/absent/ambiguous; exit codes ignored) | task-verify-tests step 8 | full |
| 10 | Rule 16: six violation lines, `check` exits 1, one shared predicate for `check` and `tests` | task-tests-field (predicates), task-tests-cmd (reuse) | full, both surfaces |
| 11 | Rule 17: 7-40 lowercase hex | task-base-sha | full |
| 12 | `set running`: existing checks first; git skipped when base_sha present; git failure refuses a task with tests (exit 2, unchanged) and moves one without; no other status touches base_sha | task-base-sha | full |
| 13 | `plan-state tests`: six-kind record, order, untrimmed values, `file`/`test` lines | task-tests-cmd | full |
| 14 | `plan-state tests` exit 2 order 1-6, nothing on stdout, other tasks ignored | task-tests-cmd | full |
| 15 | Header gains `tests` line; check line "rules 1-5 and 7-17"; usage() prints through `# Exit:`; existing usage assertion updated | task-tests-cmd | full |
| 16 | verify-tests location, POSIX sh+awk, beside git-commit-safe | task-verify-args | full (see D5 for the awk-variant half) |
| 17 | Usage `verify-tests <plan> <id>`; repo looked up only after steps 1-3 | task-verify-args, task-verify-tests step 4 | full |
| 18 | Steps 1-3 (relay plan-state stderr; `no named tests` exit 0; `no base_sha` exit 2; status irrelevant) | task-verify-args | full |
| 19 | Step 4: prune, resolve HEAD once, trap INT/TERM/HUP → cleanup, `interrupted`, exit 2 | task-verify-tests | full |
| 20 | Steps 5-6: after tree and before tree (restore non-test `file` paths to base_sha, delete paths new since base) | task-verify-tests | full |
| 21 | Step 7: each distinct file once per tree, stdout+stderr together, missing file = no output | task-verify-tests | full |
| 22 | Step 8: five labels, precedence | task-verify-tests | full |
| 23 | Step 9: remove both worktrees and temp dir on every path | task-verify-tests | full |
| 24 | Output: label lines, total line, ok/failed counting | task-verify-tests | full |
| 25 | Tails: after/before blocks by printed label, last 20 lines, `  | ` prefix, file order, after-then-before, `(no output)` | task-verify-tail | full |
| 26 | Exit codes 0/1/2; stderr "contains", stdout exact, git stdout never on stdout | task-verify-args (usage), task-verify-tests (rest) | full |
| 27 | Never writes the plan, touches shared tree/index, or commits | task-verify-tests ("shared tree untouched") | full |
| 28 | Mark running before dispatch, every task; `set` exit 2 halts; failed dispatch stays running | task-exec-dispatch | full |
| 29 | verify-tests after DONE/DONE_WITH_CONCERNS, before review, by plugin path, 600000 ms, foreground; non-0/1/2 = exit 2 | task-exec-verify | full |
| 30 | Exit 0 → reviews, output into reviewers' prompts | task-exec-verify (substitutes `{verify_tests_output}`), task-reviewer-prompts (placeholder) | full, both ends share one placeholder name |
| 31 | Exit 1 → fix round via `plan-state round` with three outcomes; exit 2 → halt | task-exec-verify | full |
| 32 | SKILL.md review flow and Review-round cap gain the step; fix round redefined | task-exec-verify | partial — see D1 |
| 33 | Implementer prompt: exact name, red-then-green, script from committed work, commit before reporting, RED-THEN-GREEN stays | task-implementer-prompt | full (re-dispatch template: see D2) |
| 34 | Spec + merged reviewer: receive output; judge only whether test tests criterion; do not re-run/re-derive; ok-absent before tail; prose as today | task-reviewer-prompts | full for the new section; conflicting existing text left — see D3 |
| 35 | Quality reviewer unchanged | task-reviewer-prompts AC 4 | full |
| 36 | plan-format.md documents five fields, rules 16-17, "1–5 and 7–17" | task-format | full |
| 37 | writing-dag-plans: name tests per testable criterion; uniqueness + rename | task-writer | full |
| 38 | plan-quality.md S17 | task-s17 | full |
| 39 | updating-dag-plans: may edit `tests:` on pending/ready; never writes `base_sha:`; preflight/check as today | task-updater | full |
| 40 | Gate-2 verifiability lens anchor | task-lens | full |
| 41 | Constraint: POSIX sh/awk under dash, bash, gawk, mawk, busybox | all script tasks | partial — see D5 |
| 42 | Constraint: suites under tests/verify-tests and tests/plan-state | all script tasks | full |
| 43 | Constraint: verify-tests in `.gitattributes` | task-verify-args | full |
| 44 | Constraint: plans without `tests:` behave as today except `base_sha:` | task-tests-field ("exactly today's output"), task-base-sha (no-tests path unchanged) | full |
| 45 | Audit record: two empirical unknowns and deferred D1 become verify-tests ACs | task-verify-tests (last criteria) | full |

Over-build / orphan sweep: every task body traces to a row above except task-repo-docs (D4). Plan-made calls 5-7 and 10 (cleanup-failed exit 2, second-signal handling, background child + wait, usage by address) trace to items the spec explicitly left to the plan (Audit record round 3, D1) or to the builder ("Internal structure"). task-base-sha's CRLF preservation follows the existing `round` behaviour (plan-state:375), not new scope.

### Findings

- **DEFERRED** · The fix-round redefinition reaches only the first sentence of SKILL.md's Review-round cap; the rest of that section and two other places still define a fix round as reviewer-only.
  - Artifact text: "In \"**Review-round cap.**\", the first sentence becomes: ... Keep the rest of the paragraph." (task-exec-verify, Implementation step 3)
  - Evidence: spec "The executor": "`SKILL.md`'s review flow and its Review-round cap section gain this step. A fix round is now \"one re-dispatch of the implementer after an ISSUES verdict or a failed `verify-tests`\"." Still inside that section after the edit: SKILL.md:78 "the fourth ISSUES verdict fails the task" and "`set` rewrites only the status line" (no longer true for `set ... running`, which will insert `base_sha:`). Outside it: plan-format.md:109 (`review_rounds` comment: "re-dispatches of the implementer after a reviewer's ISSUES verdict"), plan-format.md:242 (`failed` row: "a reviewer's fourth ISSUES verdict"). No task's Implementation or criteria touch SKILL.md:78 or plan-format.md:109/:242 (task-format's five edits are frontmatter, schema, a new subsection, rules 16-17, and the 7–15 strings).
  - Concrete failure: no wrong behaviour — the new Named-test check paragraph tells the controller to run `round` on exit 1 — but a reader of the cap section's summary, or of plan-format's `failed` semantics, is told a task can only fail the cap on a reviewer verdict.
  - Resolution: add SKILL.md:78 to task-exec-verify's edits ("the fourth ISSUES verdict or failed `verify-tests`"; "`set` rewrites only the status line" → "never touches `review_rounds:`"), and add plan-format.md:109 and :242 to task-format's edit list.

- **DEFERRED** · The re-dispatch on verify-tests exit 1 uses an implementer template that only speaks of reviewers, and no task adapts it.
  - Artifact text: "exit 1: a fix round, exactly as for an ISSUES verdict. Run `plan-state round <plan> <id>`: exit 0, re-dispatch the implementer with the `verify-tests` output as the issue list" (task-exec-verify, Named-test check paragraph)
  - Evidence: implementer-prompt.md:128 "When the spec or quality reviewer reports ISSUES, re-dispatch ..."; :135 "the {spec / quality} reviewer found issues"; :143 "Do NOT change anything that the reviewer didn't flag." task-implementer-prompt adds only a section before "## Your output" (implementer-prompt.md:66) and its criteria check only that section and the RED-THEN-GREEN field.
  - Concrete failure: the controller fills a reviewer slot with the script's output; the implementer is told a reviewer flagged named cases. Spec requirement (re-dispatch with the check's output) is still met, so this is wording drift, not a broken mechanism.
  - Resolution: in task-implementer-prompt, add one line to §Re-dispatch on review issues covering a failed named-test check (source "the named-test check", issue list = the `verify-tests` output).

- **DEFERRED** · The merged reviewer keeps its existing "Red-to-green evidence" rules, including "run the mutation yourself", unscoped to criteria without a named test, beside the new "do not re-run or re-derive" section.
  - Artifact text: "Do not re-run or re-derive those results. ... Review criteria without a named test as before." (task-reviewer-prompts, Named-test check section)
  - Evidence: merged-reviewer-prompt.md:56-67 ("Confirm the named assertion/check exists in the diff and could have failed as reported" ... "**Escalation:** ... run the mutation yourself"), :112 approval criterion "Red-to-green evidence present and coherent". Spec: "For a criterion with a verified named test, they judge only whether that test really tests the criterion, and do not re-run or re-derive it." task-implementer-prompt's new text tells the implementer RED-THEN-GREEN "is still required for acceptance criteria that have no named test", which an implementer may read as not required for named ones; the merged reviewer's :112/:62 rule calls missing evidence ISSUES.
  - Concrete failure: a merged-mode task whose test-bearing criteria are all named tests can draw an ISSUES under Code quality for "missing red-to-green evidence", spending a fix round, or the reviewer re-runs a mutation the script already proved. The new section states the spec's rule, so the requirement has an owner; the leftover text competes with it.
  - Resolution: in task-reviewer-prompts, scope merged-reviewer-prompt.md's "Red-to-green evidence" subsection and its approval bullet to "criteria without an `ok`/`ok-absent` named test".

- **DEFERRED** · task-repo-docs traces to no spec requirement, and it covers only part of its own stated goal.
  - Artifact text: "Name the new helper where the repo lists its helpers and features." (task-repo-docs)
  - Evidence: the spec's "Writing and updating plans" and "Constraints" never name README.md or CLAUDE.md for edits; the task cites only plan Context calls 8-9. Its README edits touch README.md:11-12; README.md:120-126 ("The four helper scripts have real test suites" and the per-suite command list) is not in its Implementation, so after the plan it says "four" with five helpers and lists no verify-tests suite.
  - Concrete failure: none to behaviour; the README helper section is stale after the run.
  - Resolution: keep the task (it closes enumerations S17 makes stale and puts verify-tests under CLAUDE.md's POSIX rule), and add README.md:120-126 to it, or narrow its title to what it edits.

- **DEFERRED** · The awk-portability half of the POSIX constraint is not restated in the two verify-tests tasks that write the awk classifier and tails, and CLAUDE.md does not list verify-tests until task-repo-docs, which may run concurrently with them.
  - Artifact text: "Create the helper `skills/executing-dag-plans/verify-tests` in POSIX sh and awk" (task-verify-args only); task-verify-tests and task-verify-tail bodies have no portability sentence (`rg 'dash|mawk|busybox|gawk|POSIX'` over the plan: only lines 112, 124, 132-133 (Context), 525, 556-557, 618-619, 810).
  - Evidence: spec Constraints: "POSIX sh and awk under dash and bash, and under gawk, mawk and busybox awk". The plan's own Context says "Every task restates the parts of it that it needs, because the reviewers see only the task body" (L54-55). Implementers and reviewers do get CLAUDE.md injected (implementer-prompt.md:35-37, spec-reviewer-prompt.md:42-44), but CLAUDE.md:5-9 names only the four existing helpers; task-repo-docs depends only on task-verify-args, so it can land after task-verify-tests is dispatched.
  - Concrete failure: a gawk-only call (`gensub`, `asort`) or `\x` escape in the classifier passes the suite on a gawk host and ships, breaking the charter rule on mawk/busybox. Plausible but not likely given "POSIX sh and awk" in the first task.
  - Resolution: add one sentence to task-verify-tests and task-verify-tail restating the awk rule (no `gensub`, `strftime`, `asort`, `\x`).

### Checked, no finding
- Every numbered spec requirement in "The plan format", "Validation rules", "`plan-state` changes", "`verify-tests`", "The executor", "The prompts", "Writing and updating plans" and "Constraints" has an owning task (matrix rows 1-45). Interface strings the hidden suite will pin (all rule 16/17 lines, `refused <id>: cannot read HEAD for base_sha`, `has a bad tests entry; run: plan-state check`, the six-kind `tests` record, `no named tests`, `no base_sha (set the task running first)`, `interrupted`, label/total/tail formats) match the spec byte for byte in the plan.
- Two-surface requirements are both owned: shared rule 16 predicate (task-tests-field writes, task-tests-cmd reuses); `{verify_tests_output}` (task-exec-verify fills, task-reviewer-prompts declares, same name in both); case-name uniqueness (verify-tests `ambiguous` and writing-dag-plans guidance); `base_sha` (written only by task-base-sha's `set running`, refused to `/update` by task-updater, validated by rule 17, documented by task-format); ok-absent before tail (task-verify-tail emits, task-reviewer-prompts consumes).
- Both review diagrams (split, merged) get the verify step; no third review mode exists (SKILL.md:39).
- All S1–S16 and 7–15 enumerations in the tree are either edited by a task or deliberately kept per Context call 8.
- Plan-made calls (cleanup-failed exit 2, second-signal handling, background `wait`, usage by sed address, CRLF on the inserted line) trace to spec delegations (Audit record round 3 D1; "Left to the builder") or existing plan-state behaviour, not new scope.
- resolve-declared-paths will not read a `tests:` block as `files:` items (resolve-declared-paths:106-113), so "plans without `tests:` behave as today" has no hidden second surface there.

### Out of lens
- task-exec-dispatch says to put the paragraph "at the start of step 4's text, before \"**Dispatch in parallel:**\"" (plan L925-926), but its AC requires a line matching `^\s*\*\*Mark running first` after the line starting `4. ` (L940-942). Read literally, the two placements conflict (coherence/verifiability).
