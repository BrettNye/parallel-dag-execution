## Lens: ambiguity
## Charter: CLAUDE.md (repo root). No AGENTS.md, nested CLAUDE.md or .claude/audit-charter.md. CLAUDE.md says nothing about this diff's subject (how verify-tests builds the before tree); it constrains only the helper scripts' shell portability and the test-runner shape.

Scope: diff-scoped round 3. I audited the round-3 diff (plan L662-667, step 6; L759-764, new case) and the sections that depend on it: the rest of task-verify-tests (L631-841), task-verify-tail (L842-933), task-reviewer-prompts (L1119-1175) and spec:225-245. I read prior-findings.md in full and do not re-report anything listed there (D8, D-tail-stdout and J4 in particular). Downstream context: none was given beyond the plan, and every task is pending. I ran no probes, and I wrote nothing in the tree except this report.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| Spec step 6 says non-test `file` paths are put back and "A path that did not exist at base_sha is deleted", and that the before tree keeps "the task's finished tests" | plan L662-667 | spec:228-231 | VERIFIED. The spec's deletion sentence does not say whether test files are excluded, and its "So ... finished tests" sentence settles that they are. The plan's "such a path" plus "A test file is never put back or deleted, even one the task created" matches the spec's intent. |
| A `<file>` missing from a tree counts as a run with no output, so a wrong build gives `ok-absent` | plan L763-764 | plan L673-674 (step 7); spec:233-234; label order plan L683-687, spec:238-245 | VERIFIED. A build that deletes the new suite makes `y` absent before, and with `y` passing after, the label is `ok-absent` with exit 0. The new case expects `not-red` with exit 1, so it tells the two builds apart. |
| Rule 16 requires the test file to be in `files:` | plan L761 | spec:134-136 | VERIFIED |
| mkrepo's normal fixture commits the suite before `base_sha` | plan L759-760 ("a mkrepo variant that does not commit the suite before base_sha") | plan L729-733 | VERIFIED. mkrepo commits, sets T1 running, then commits the lib.sh change, so the suite exists at base. The case correctly asks for a variant. |
| The ok-absent case still has a correct-build route to absence | plan L747-751 | plan L662-667 | VERIFIED. The absence must come from the suite stopping early when a non-test file the task creates is missing. Step 6 still deletes that file ("such a path"), so the route still exists. |
| task-verify-tail's before-block rule does not depend on how the before tree was built | plan L861-863 | plan L896 | VERIFIED. The rule keys on the printed label only. |

### Findings

- **DEFERRED** · The case "trees: before tree deletes a path new since base" now says more than step 6 allows.
  - Artifact text: "\"trees: before tree deletes a path new since base\": a task file that did not exist at `base_sha` is absent in the before tree (its suite reports so on a fail line), giving `ok`." (plan L781-782)
  - Evidence: Step 6 now says "such a path that did not exist at `base_sha` ... is deleted. A test file is never put back or deleted, even one the task created." (L664-666). The new case directly above it (L759-764) is about a task file that did not exist at `base_sha` and is *not* absent in the before tree. Read alone, "a task file" in L781 includes test files.
  - Concrete failure: none reaches a build. The parenthetical "(its suite reports so on a fail line)" needs the suite to exist in the before tree, so the file in question can only be a non-test file. The only cost is that a reader sees two neighbouring case names that look contradictory.
  - Resolution: in L781, change "a task file" to "a task file that is not a test file" (or "a non-test task file").

No BLOCKING findings. Round 2's B1 is fixed, and the fix is complete within this lens:
- The deletion clause is now limited to non-test paths.
- The test-file exemption covers files the task created and files the task modified.
- The new case can fail: a build that deletes the new suite prints `ok-absent` and exits 0, but the case expects `not-red` and exit 1.

### Checked, no finding
- **The bare term "test file" in L665.** The previous sentence defines it as "the `<file>` of one of the task's `test` lines" (L662-663), and verify-tests has no other way to tell what a test file is: its only input is `plan-state tests` (spec:214-216). Only one implementation is possible. A suite helper that is in `files:` but named on no `test` line is still put back, and that is what the spec says (spec:228-229).
- **New case: which entry is checked.** The case does not quote the `tests:` entry, but "with case `y`" together with the total "0 ok, 1 failed" fixes it as the single entry `t/demo.test.sh :: y`. This is the same pattern as the accepted neighbouring case at L754-758.
- **New case: can it be false?** Yes. A correct build gives `not-red` and exit 1. A build that deletes the new suite gives `ok-absent` and exit 0. A build that tries `git checkout <base> -- <suite>` on a path that is absent at base either fails (and exits 2) or ends up deleting the suite. All of these fail the case.
- **New case: "which passes on the base code".** `y` must also pass after, or step 8 labels it `not-green` first (L684). The case's own expected `not-red` result forces the fixture to make `y` pass in both trees, so this is not ambiguous. The neighbouring case at L754-758 has the same shape and has already been accepted.
- **Step 6 against the ok-absent case (L747-751) and the EU1 one-off (L819-822).** Both rely on the before tree keeping the task's finished test files, which is now stated outright. They agree with the fix.
- **task-verify-tail (L858-871) and the ok-absent text in task-reviewer-prompts (L1130-1135, L1150).** The diff introduces no new ambiguity in either. The tension in the reviewer parenthetical is prior D8 and is not re-reported. The before-block rule keys on labels only.
- **Plan summary (L47-49).** It does not restate step 6's put-back or delete rule, so nothing there contradicts the fix. I checked with `rg 'put back|before tree|did not exist at|created'` and `rg 'deleted|ok-absent'` over the plan.

### Out of lens
- The fixtures for task-verify-tail need `ok-absent` entries: "tails: spec example order" at L914 and "tails: one file gives after then before" at L921. The task body does not say that, after this fix, absence can only come from a suite that stops early (L747-751). This is a context-sufficiency question, and the cost is a fixture rewrite during implementation.
