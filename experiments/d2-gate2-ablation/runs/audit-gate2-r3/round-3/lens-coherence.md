## Lens: coherence (round 3, diff-scoped to commit 5d95374)
## Charter: CLAUDE.md read. It cites no file:line, and no AGENTS.md, nested CLAUDE.md or audit-charter exists. Downstream artifacts: none (all tasks pending, no code landed). No probes run; this is a read-only comparison of the plan against itself.

### Grounding table
| Assumption | Where in artifact | Verified at | Status |
|---|---|---|---|
| Step 6 now says "such a path" (non-test `files:` paths only) and "A test file is never put back or deleted, even one the task created" | task-verify-tests step 6, plan L662-667 | plan L662-667 read in full | VERIFIED |
| The new case's "as rule 16 requires" matches rule 16 | task-verify-tests criterion, L759-764 | plan L188-189 (`rule 16: <id> test file <file> is not in its files:`) and L258-259 (case "rule 16: test file outside files: is named"). Spec:70-72 is the block-form rule and does not bear on this. | VERIFIED |
| The new case's mkrepo variant is compatible with the mkrepo fixture | L729-733 vs L759-761 | The fixture commits the suite before `base_sha`. The variant commits it after (the task's commit adds it). Both sit in one criterion that names itself "a mkrepo variant". | VERIFIED |
| The new case's expected label follows from steps 6, 7 and 8 | L759-764 vs L675-687 | Suite kept in the before tree (step 6), run (step 7), `y` passes before and after (step 8: not-green no, not-red yes) gives `not-red`, `0 ok, 1 failed`, exit 1 (L691-695). A delete-the-suite build leaves `y` absent, which gives `ok-absent`. | VERIFIED |
| "trees: new suite file is kept in the before tree" appears once as a case name | whole plan | rg of the case name: L759 only (L1507 is the audit-record paraphrase in lower case, out of scope) | VERIFIED |
| Other tasks restate the before-tree rule | whole plan | rg for `before tree`, `put back`, `deleted`, `restor`, `did not exist at`, `red by absence`: only Context L48 (generic "builds a before tree"), task-verify-tests, and the audit record. No other task restates step 6. | VERIFIED |

### Findings
None. No BLOCKING, DEFERRED, EMPIRICAL-UNKNOWN or UNVERIFIABLE item in this lens.

### Checked, no finding
Checked set, enumerated. The contract is "the before tree's content rule (step 6) and what `ok-absent` / `not-red` therefore mean". I compared every passage that produces, consumes, asserts against or documents it. Eleven passages across four tasks, all consistent:

task-verify-tests (7 passages):
1. Step 6 (L662-667) states the rule. "such a path" binds to the previous clause's non-test paths. The new sentence then exempts test files from both put-back and deletion. The two sentences agree and the antecedent is clear.
2. Step 7 (L668-674): "A `<file>` that does not exist in a tree counts as a run with no output". Under the new rule a test file is absent in the before tree only when it is also absent at HEAD, so this sentence stays true and does not conflict.
3. Step 8 labels (L682-687): `ok-absent` and `not-red` agree with the new case's expected outputs. Precedence (not-green, then not-red, then ok-absent) gives `not-red` for the case.
4. mkrepo fixture (L729-733): the committed suite and `files:` list are compatible with the new case, which declares itself a variant of this fixture.
5. Criterion "trees: absent before is ok-absent" (L747-751): its last sentence ("the before tree keeps the task's finished test file (step 6)") agrees with the new rule. Its absence comes from a non-test file the task creates being deleted, which is the "such a path" clause.
6. Criteria "new case passing on old code is not-red" (L754-758) and the new "new suite file is kept" (L759-764). They are the two branches of one rule: not put back when the file existed at base, not deleted when it did not. They do not overlap and neither is redundant. Case names are unique.
7. Criterion "trees: before tree deletes a path new since base" (L781-782) and EU1 (L820-822). The first concerns a non-test task file and is consistent with "such a path" deletion. EU1's "the before tree kept the task's finished test file" is consistent with the new sentence.

Other tasks (4 passages):
8. task-verify-tail (L858-871, L914-927): before blocks for `not-red` and `ok-absent` are unaffected, because they depend only on labels. "A run with no output (including a file missing from the tree)" is still reachable, via a file missing at HEAD or from the after tree. Consistent.
9. task-reviewer-prompts (L1133-1135, L1150, L1164): consistent with the rewritten rule. The "(missing because the task had not built it yet)" parenthetical sits uneasily beside it, but that is the accepted D8 and is not re-reported.
10. Context (L48) says only "builds a before tree and an after tree". No restatement, no conflict.
11. task-verify-args (L561-627) is the stub that task-verify-tests replaces. It says nothing about trees.

Structural spot check: the diff touches no `depends_on`, `files:` frontmatter, task id or mermaid node. The task-verify-tests frontmatter (L634-641) and the plan's graph node (L14) are unchanged and agree.

Not checked (out of the diff scope or not in this lens): the whole-document structure, which round 2 verified (16 nodes, 8 edges), and spec-vs-plan agreement on step 6 (spec:228-231 reads "A path that did not exist at base_sha is deleted" without the test-file carve-out), which belongs to the coverage lens.

### Out of lens
- Coverage: the frozen spec's step 6 (spec:228-231) lacks the plan's test-file carve-out. The plan now states the rule more precisely than the spec. Spec-vs-plan, so it is not mine to classify. It is presumably intended as a plan clarification.
