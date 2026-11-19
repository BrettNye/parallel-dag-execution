## Lens: verifiability
## Charter: CLAUDE.md (repo root). No AGENTS.md, nested CLAUDE.md or .claude/audit-charter.md. CLAUDE.md requires each script to have a suite under tests/<suite>/ ending in `RESULT: N passed, M failed` and exiting non-zero on failure; the plan's acceptance criteria follow that shape.

Scope: round 3, diff-scoped. Diff 09fed21..5d95374 (round-3/diff.patch): task-verify-tests step 6 (plan L662-667) and the new case "trees: new suite file is kept in the before tree" (plan L759-764). Dependents read: rest of task-verify-tests (L631-841), task-verify-tail (L842-933), task-reviewer-prompts (L1119-1175), spec L205-247. Prior findings read in full; nothing below re-reports an accepted DEFERRED item (D-tail-stdout, D-before-content and D8 touch this area and stay as accepted).

Downstream context: none beyond the plan itself (every task pending, no implementation landed), as the dispatch states.

No probes were run. Everything below comes from reading the files.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Status |
|---|---|---|---|
| The spec's step 6 says test files are kept and other `files:` paths are put back or deleted, and the before tree "has the task's finished tests" | plan L662-667 | spec L228-231 | VERIFIED (the plan narrows the spec's unqualified "A path that did not exist at base_sha is deleted" to non-test paths. That is consistent with spec L230 "has the task's finished tests") |
| `ok-absent` means absent in the before tree and `not-red` means passed in the before tree, in that precedence | new case L759-764 | plan L683-687; spec L238-245 | VERIFIED |
| A `<file>` missing from a tree counts as a run with no output, so it is absent and gets `ok-absent` | the wrong-build prediction in L763-764 | plan L673; spec L233-234 | VERIFIED |
| Rule 16 needs the test file in `files:`, and nothing requires it to exist at `base_sha` | "it is in T1's `files:`, as rule 16 requires" L760-761 | spec L130-143 (rule 16 checks shape, membership in `files:`, repeats and the block form; it does not check that the file exists); plan L287-305 (`set running` reads only HEAD) | VERIFIED. The variant fixture can be set up |
| The total counts `not-red` as failed and the exit is 1 | L762 | plan L691-695 | VERIFIED |
| No other text in the plan describes the before-tree rule differently | dependents | `rg -n "put back\|is deleted\|kept in the before\|keeps the task\|finished test"` over the plan: hits only at L663-667, L750-751, L757, L759, L822, L1089, all consistent | VERIFIED |

### Findings

None.

### Checked, no finding
- **The new case discriminates the B1 wrong build.** It asserts the exact stdout (`not-red` label line plus `0 ok, 1 failed`) and exit 1. A build that deletes a test file the task created runs nothing for it in the before tree (L673), so the case is absent there. That build labels it `ok-absent` (L686) and prints `1 ok, 0 failed` with exit 0, so the case fails. The prediction in L763-764 is correct.
- **The new case cannot pass on a crash.** `not-red` needs the case to be *passed* in the before tree. That is positive evidence that the suite file existed and ran there. A crash, an exit 2 or an empty stdout cannot produce the expected string. No companion assertion is needed.
- **Both halves of the new step-6 sentence are pinned.** "never put back" is pinned by "trees: new case passing on old code is not-red" (L754-758, accepted as solid in round 2). "never deleted, even one the task created" is pinned by the new case. The opposite wrong build, which deletes non-test paths too little, is pinned by "trees: before tree deletes a path new since base" (L781-782): without deletion the suite would pass before and the label would be `not-red`, not `ok`.
- **The new case does not depend on whether the task's commit changes `lib.sh`.** `y` passes on the base code by construction, and the expected label `not-red` implicitly requires that `y` still passes after (otherwise `not-green`, L684). Both the correct and the wrong build are told apart either way.
- **Case names are unique.** The new name differs from every other quoted name in L745-810, which satisfies "each name appears once" (L741-742).
- **The ok-absent case (L747-751)** still agrees with step 6 as rewritten. The before tree keeps the task's test files, so `ok-absent` can only come from the suite stopping early.
- **task-verify-tail (L858-871):** the new case yields `not-red`, which gets a before block once task-verify-tail lands. That is the already-accepted D-tail-stdout and D-before-content, and it is not new. The diff does not change the tail rules.
- **task-reviewer-prompts (L1133-1135, L1150):** the diff does not touch them. The parenthetical is the accepted D8.
