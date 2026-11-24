## Lens: grounding
## Charter: CLAUDE.md (POSIX sh/awk, test-suite conventions); no AGENTS.md, nested CLAUDE.md or audit-charter.md. No downstream artifacts (all tasks pending, no code landed); the verdict below is against the plan text and the frozen spec only. Round 3, diff-scoped to commit 5d95374. No probes run (nothing in the diff is executable; the new `verify-tests` script does not exist yet).

### Grounding table
| Assumption | Where in artifact | Verified at file:line | VERIFIED / CONTRADICTED / NOT-FOUND / UNVERIFIABLE |
|---|---|---|---|
| Rule 16 requires every `test` file to be in the task's `files:` ("as rule 16 requires") | plan L761 | plan L188-189 (`rule 16: <id> test file <file> is not in its files:`); spec:136 | VERIFIED |
| `plan-state tests` prints `file <path>` lines and `test <file>\t<case>` lines, so step 6 can tell which `files:` paths are test files | plan L662-663 (step 6) | plan L406-407, L414-418 (task-tests-cmd output contract) | VERIFIED (producer is a planned task, `task-verify-tests` depends on it through `task-verify-args`) |
| Step 6's new sentences agree with the spec's step 6 | plan L662-667 | spec:228-231 ("Every `file` path that is not a `<file>` of one of the task's `test` lines is put back ... A path that did not exist at `base_sha` is deleted. So the before tree has the task's finished tests") | VERIFIED. "such a path" and "a test file is never put back or deleted" follow the spec's first sentence and its "finished tests" conclusion |
| A suite absent at `base_sha` can exist in T1's before tree, because the before tree is a worktree at the same HEAD SHA as the after tree, with only non-test `files:` paths reverted | plan L659-667 | plan L659-662 (both trees from one SHA); spec:228 | VERIFIED. The suite is in HEAD, is a test file, and is never touched, so `y` runs and passes on the base `lib.sh` and gives `not-red` |
| An implementation that deletes the suite from the before tree labels `y` `ok-absent` | plan L763-764 | plan L673-674 (a missing `<file>` is a run with no output); L686 (absent before and passed after is `ok-absent`) | VERIFIED. The case discriminates the B1 defect |
| Setting T1 running before the suite is committed still records `base_sha` | plan L759-761 (mkrepo variant) | plan L300-301 (`rev-parse HEAD` of the plan's directory, no clean-tree or file-existence precondition); L296 (only `tests:` plus unreadable HEAD refuses) | VERIFIED. The variant only needs a commit before `set running`, as mkrepo already has |
| The new case differs from "new case passing on old code is not-red" (L754-758) and from "before tree deletes a path new since base" (L781-782) | plan L754-782 | L754-758: suite exists at base without `y`; L759-764: suite absent at base; L781-782: a non-test path | VERIFIED. Three distinct implementation mistakes (restore test files, delete new test files, fail to delete new non-test paths), each caught by exactly one case |
| `mkrepo` "variant" is derived from the L729-733 fixture | plan L759-760 | plan L727-733 (the sketch is illustrative, with a single mkrepo and no parameters) | VERIFIED (a variant is free for the implementer to write; see the DEFERRED item) |
| The suite file under test, `tests/verify-tests/verify-tests.test.sh`, and the script `skills/executing-dag-plans/verify-tests` are new | task-verify-tests `files:` | ground-truth.md table 1: both ABSENT, declared in create-tasks | VERIFIED as genuinely new. The parent directories `skills/executing-dag-plans/` and `tests/` exist, and `tests/verify-tests/` is created by task-verify-args |
| task-verify-tail's before-block rule (not-red or ok-absent) still holds with a kept new suite | plan L861-863 | The before output file exists whenever the before run is not absent. A kept suite gives real before output | VERIFIED. No conflict with the diff |
| task-reviewer-prompts' ok-absent text still fits | plan L1131-1136, L1150 | Spec:241-244 (absence is red; may also be an unrelated break). The "missing because the task had not built it yet" parenthetical is the already-accepted D8 | VERIFIED, with D8 already DEFERRED |

### Findings

No blocking findings. The round-2 blocker (B1) is fixed correctly and completely as far as grounding goes.

- **DEFERRED** · The new case's "mkrepo variant that does not commit the suite before `base_sha`" is not tied to a stated mechanism, so the implementer must decide whether the variant parameterises mkrepo or writes a second helper.
  - Artifact text: "(a mkrepo variant that does not commit the suite before `base_sha`)"
  - Evidence: plan L727-733 shows mkrepo as a comment sketch only ("names are illustrative"), and the other nine tree cases (L745-764, L777-782) also need unstated fixtures.
  - Concrete failure: none; implementers write fixtures from the criterion in every neighbouring case. Style-level.
  - Resolution: none needed.

### Checked, no finding
- Step 6 text (L662-667) against spec:228-231: the plan's reading, test files are neither put back nor deleted, follows the spec's first sentence ("not a `<file>` of one of the task's `test` lines") and its conclusion ("the task's finished tests"). The plan did not invent a rule.
- New acceptance case (L759-764): both ends hold. The producer, `plan-state tests`' `file` and `test` lines (L406-407), exists in the plan as a prior task. The consumer, `verify-tests` step 6 and step 7 (a missing file is a run with no output), gives `ok-absent` for a deleting implementation and `not-red` for a correct one. The `0 ok, 1 failed` total counts `not-red` as failed (L693-694), and the exit is 1 (L694-695).
- Rule 16's "test file in `files:`" requirement is real (L188-189, L224), so the new case's fixture is a valid plan and not one `check` would refuse.
- Neighbouring cases: "trees: absent before is ok-absent" (L747-751) already says the before tree keeps the task's finished test file, which agrees with the diff.
- Step 7 and the Implementation sketch (L704-725) do not touch step 6's deletion logic, so the diff changes nothing there.

### Out of lens
- None.
