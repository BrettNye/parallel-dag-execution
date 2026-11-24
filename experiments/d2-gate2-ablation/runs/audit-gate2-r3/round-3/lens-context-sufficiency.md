## Lens: context-sufficiency (gate 2, round 3, diff-scoped to 5d95374)
## Charter: CLAUDE.md (repo root). No AGENTS.md, nested CLAUDE.md, or .claude/audit-charter.md. CLAUDE.md cites no file:line, so it says nothing about the before-tree rule under audit.

Scope: the diff in round-3/diff.patch (task-verify-tests step 6, plan L662-667, and the new case at L759-764), plus the text that depends on it: the rest of task-verify-tests (L631-841), task-verify-tail (L842-933), task-reviewer-prompts (L1119-1175), and spec L225-245. The audit-record hunk was not audited. Downstream context: none was supplied. This plan is the only consumer of the spec, and no implementation has landed. Probes: none run. Every claim below comes from reading the files.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| The record gives `file` lines (one per `files:` item) and `test <file>\t<case>` lines, so "the `<file>` of one of the task's `test` lines" can be computed from data the implementer has | step 6, L662-663 | spec:173-184. Restated to the implementer in task-verify-args L546-547 (split at tab, `IFS= read -r`); the dependency's committed stub reads `test ` lines at plan L583 | VERIFIED |
| The deletion clause now applies only to non-test paths | L664 "such a path" | plan L662-666 read in sequence | VERIFIED |
| The exemption covers test files the task created | L665-666 | plan L665-666 | VERIFIED |
| The new case names an existing fixture builder (mkrepo) with the suite path and the `files:` list it needs | L759-761 | plan L729-733 (mkrepo sketch in the same task body: `t/demo.test.sh`, `files: [lib.sh, t/demo.test.sh]`, commit, then set running, then commit) | VERIFIED |
| A wrong build (deleting the new suite) gives a different observable result from a correct build | L762-764 | plan L673 (a missing `<file>` is a run with no output), L686 (absent before gives `ok-absent`), L692 (ok-absent counts as ok). So the wrong build prints `ok-absent`, `1 ok, 0 failed` and exits 0, while the case expects `not-red`, `0 ok, 1 failed` and exit 1 | VERIFIED |
| `not-red` also needs `y` to pass in the after tree, and the case pins that | L761-762 | plan L684-685 (not-green comes before not-red). "The run gives `not-red`" fixes the after result | VERIFIED |
| The new case name is unique | L759 | `rg` on the plan: the case name appears once | VERIFIED |
| The other cases that depend on step 6 still agree with it | L747-751, L754-758, L781-782, L820-822 | plan lines as cited | VERIFIED |
| The implementer-facing summary of the before tree agrees | L1089 | plan L1089 "with your finished test files" | VERIFIED |
| Spec step 6 supports the narrowing | step 6 | spec:228-231 ("So the before tree has the task's finished tests") | VERIFIED |

### Findings

No blocking findings. Nothing new is deferred, empirical-unknown or unverifiable either.

The JR1 fix is complete as far as this lens can tell. An implementer who sees only task-verify-tests' body and task-verify-args' output can build step 6 without guessing:
- The paths to put back or delete are the `file` lines minus the `<file>`s of the `test` lines (L662-663).
- The git commands for each operation are given inline (L664-665).
- The test-file exemption covers both operations and includes files the task created (L665-666).

A reviewer who sees only the task body can check the new rule with the new case, and the case states the wrong build's label (`ok-absent`) next to the right one.

### Checked, no finding
- **The new case's fixture is fully specified in the task body.** "a mkrepo variant that does not commit the suite before `base_sha`" refers to the mkrepo sketch at L729-733 in the same task. The case states the suite path and its membership in `files:` ("as rule 16 requires"), the added case `y`, the condition that `y` passes on base code, the expected label, the total and the exit code. The case does not say outright that the variant plan's `tests:` names `t/demo.test.sh :: y`, but `0 ok, 1 failed` fixes the single entry as `y`. This is the same pattern as the round-2 case at L754-758, which earlier rounds accepted.
- **"A test file" (L665) is defined in context.** The sentence before it defines the class as "the `<file>` of one of the task's `test` lines", and L757 says "the task's test files". The implementer does not have to decide whether a test-like `files:` path with no named entry is exempt.
- **The neighbouring tree cases agree with the changed step.**
  - "trees: absent before is ok-absent" (L747-751) already requires the absence to come from the suite stopping early, which is consistent with test files now never being deleted.
  - "trees: before tree deletes a path new since base" (L781-782) says "its suite reports so on a fail line", so the deleted path is a non-test file and the suite is still present. This agrees with "such a path".
  - The EU1 one-off (L820-822) relies on the before tree keeping the finished test file, which is unchanged.
- **Step 7's missing-file rule still holds.** "A `<file>` that does not exist in a tree counts as a run with no output" (L673) can now apply in the before tree only when the file is also missing at HEAD. It does not contradict the new rule.
- **task-verify-tail (L842-933).**
  - Its fixtures for `ok-absent` ("tails: spec example order", "tails: one file gives after then before") must now make `a.sh`'s case absent before by having the suite stop early. A test file that is new with the task no longer works, because it is kept in the before tree.
  - The task body does not say this. However, the immediate dependency's committed suite contains the "trees: absent before is ok-absent" fixture, which is built exactly that way. task-verify-tail's `files:` include that same suite. A naive fixture would also fail loudly on the exact `ok-absent` label line rather than pass a wrong build. So the dependency's output is enough, and this is not a finding.
  - "tails: no output shows placeholder" (a test file missing from the after tree) still holds.
  - The new case's exact-stdout check will break once task-verify-tail adds a `(before)` block for its `not-red` entry. That is the accepted D-tail-stdout class, and it is not re-reported here.
- **task-reviewer-prompts (L1130-1150).** The ok-absent text is unchanged by the diff. Its parenthetical "(missing because the task had not built it yet)" is accepted D8 (JR1.3, deliberately not applied), and it is not re-reported here.
- **No new pointer-only requirement was introduced.** The diff inlines its rule and adds no "per spec" or "as above" reference. The task's existing opening pointer ("Spec: ...", L647-648) sits alongside steps 4-9, which are fully inlined. That was cleared in earlier rounds.
