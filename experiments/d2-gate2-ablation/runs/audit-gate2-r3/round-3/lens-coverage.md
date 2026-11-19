## Lens: coverage
## Charter: CLAUDE.md (repo root). No AGENTS.md, nested CLAUDE.md or .claude/audit-charter.md exists. CLAUDE.md has no rule that bears on step 6 or the new case.

Scope: round 3, diff-scoped (09fed21..5d95374). In scope: task-verify-tests step 6 (plan L662-667) and the new case (L759-764), plus the parts that depend on them: the rest of task-verify-tests (L631-841), task-verify-tail (L842-933), task-reviewer-prompts' ok-absent text (L1119-1175), and spec:225-245. Downstream context: none beyond the plan. Every task is pending and no implementation has landed, so nothing here can be STALE. No probes were run.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| Spec step 6 puts back every non-test `file` path and deletes one that is new since base, so that the before tree keeps "the task's finished tests" | L662-667 | spec:228-231 | VERIFIED. The plan's "such a path" plus "A test file is never put back or deleted" is the reading the spec's own consequence sentence needs. |
| Spec's ok-absent assumes a brand-new suite still runs in the before tree and stops early when the script is missing | L747-751, L763-764 | spec:241-244 | VERIFIED. If the new suite were deleted, it would not "stop at its first line". It would not run at all. |
| Rule 16 requires a test entry's `<file>` to be in the task's `files:` | L760-761 ("as rule 16 requires") | spec:135-136 | VERIFIED |
| Nothing at `set running` or in rule 16 requires the test file to exist at `base_sha`, so the mkrepo variant is legal | L759-760, L729-732 | spec:130-147 (rule 16/17 lists, no existence check); spec:156 (set keeps its existing checks) | VERIFIED. Both searches were `rg -n "exist"` over the spec and a read of rule 16/17. Neither found an existence check. |
| Step 6 is the only place in the plan that describes how the before tree is built, so no second surface needs the same exception | (absent elsewhere) | Searched with `rg -n -i "before tree\|deleted\|put back\|did not exist"` over the plan and checked the task list for shipped-doc tasks. The only hits are L48 (Context, a summary) and task-verify-tests' own lines. | VERIFIED |
| Labels and totals in the new case follow the label order | L762 | plan L683-687; spec:238-245, :261-262 | VERIFIED. `y` passes before, so it gets not-red (rule 3), which counts as failed: `0 ok, 1 failed`, exit 1. |

### Findings
None.

### Checked, no finding
- **Requirement → task, spec step 6 (spec:228-231):** task-verify-tests step 6 (L662-667) owns all of it. That covers putting back non-test paths, deleting non-test paths that are new since base, and keeping the task's tests, including tests the task created. Two cases now discriminate both halves of the test-file rule. "Trees: new case passing on old code is not-red" (L754-758) catches a build that puts the test file back. "Trees: new suite file is kept in the before tree" (L759-764) catches a build that deletes it. The deletion of non-test paths stays pinned by "trees: before tree deletes a path new since base" (L781-782). Round 2's B1 is closed, and the fix is neither partial nor wrong.
- **Discrimination of the new case:** a build that deletes the new suite from the before tree runs a missing file. Per step 7 (L673), that counts as a run with no output, so `y` is absent and gets ok-absent with `1 ok, 0 failed`, exit 0. A correct build gives not-red with exit 1. Both stdout and exit code separate the two.
- **No over-build:** the added sentence and the added case trace to spec:228-231 and :241-244. Neither adds behaviour the spec does not ask for.
- **Dependents:**
  - The ok-absent case (L747-751) and the EU1 one-off (L819-822) both rely on the before tree keeping the task's test files. They agree with the new rule.
  - task-verify-tail (L861-863) prints a before block for not-red. The new case is one more not-red case whose exact stdout changes once that task lands. This is the accepted D-tail-stdout and is not re-reported.
  - task-reviewer-prompts' "(missing because the task had not built it yet)" (L1150) is the accepted D8 and is not re-reported. The diff does not make it worse.
- **Name uniqueness:** the new case name appears once in the criteria list (L759).

### Out of lens
- Step 6's "A test file" (L665) could be read as any test-like file, such as a fixture in `files:`, instead of "the `<file>` of a `test` line" from L663. On that reading a deleted fixture would be kept, which conflicts with spec:244 ("such as a deleted fixture"). This is for the ambiguity lens.
