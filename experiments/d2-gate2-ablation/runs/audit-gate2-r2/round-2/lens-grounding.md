## Lens: grounding (round 2, diff-scoped)
## Charter: C:/Users/Brett/d2-runs/pde-d2-gate2/CLAUDE.md (no AGENTS.md, no .claude/audit-charter.md). Downstream context: the plan is the only consumer; all 16 tasks pending, no code landed.

### Grounding table
| Assumption | Where in artifact | Verified at | Status |
|---|---|---|---|
| Case `round on "2" writes review_rounds: 3` exists in tests/plan-state/plan-state.test.sh | task-verify-tests, EU1 | The test file has `chk "round on $q writes review_rounds: 3"` at line 775, inside `for q in '"2"' "'2'"` (T31, lines 767-778). The label expands to `round on "2" writes review_rounds: 3`. The `'2'` pass prints a different name, so the name is unique. | VERIFIED |
| That case was added in 76ed77d | same | `git show 76ed77d -- tests/plan-state/plan-state.test.sh` adds the whole T31 block. `git show 76ed77d^:tests/plan-state/plan-state.test.sh` has no `T31`. `git merge-base --is-ancestor 76ed77d HEAD` succeeds. | VERIFIED |
| It fails at 76ed77d^ (old plan-state, finished test file) | same | PROBED, outside the repo, in a temp dir. It held `git show 76ed77d^:skills/writing-dag-plans/plan-state` plus HEAD's test file and `docs/superpowers/plans`, and I ran the suite once. It printed `FAIL: round on "2" writes review_rounds: 3 (expected [review_rounds: 3] got [review_rounds: "2"])`, once. That line matches the fail-line rule `<prefix><case> (`. The same run printed `PASS: round on "2" counts to 3`, which confirms the round-1 B1 finding that the old name was wrong. | VERIFIED |
| `76ed77d^` is a commit, so `base_sha:` can be its full SHA | same | `git rev-parse 76ed77d^` = 1757d4db7e16bc95f8c13aeae1a6c7dba5735583 | VERIFIED |
| `.scratch/` is git-ignored | EU1 ("plan under the ignored `.scratch/` directory") | .gitignore:16 `.scratch/` | VERIFIED |
| `git worktree prune` keeps a registration while its directory exists, and removes it once the directory is gone | Context call 7; step 4; KILL criterion | PROBED in a temp repo (git 2.56.0.windows.1). I registered 2 detached worktrees under a `mktemp -d` dir. `prune` left `worktree list` at 3 lines. After `rm -rf` of the dir, `list` still showed 3. After a second `prune` it showed 1. | VERIFIED |
| The spec already requires `git worktree prune` | Context call 7 ("which the spec already requires") | spec:221 | VERIFIED |
| `implementer-prompt.md:19` is the frontmatter line of the "MUST receive" list | task-implementer-prompt edit 1 | Line 16 is "The implementer MUST receive:". Line 19 is "- This task's frontmatter (id, depends_on, files)." | VERIFIED |
| Template `## Task spec` has a `depends_on:` line followed by `### Body` | edit 2 and criteria | Lines 88 (`## Task spec`), 94 (`depends_on: ...`), 96 (`### Body`). All are inside the code fence. | VERIFIED |
| `rg -n 'tests:. entries, when present'` prints one line and the line number is below `^## Task spec` | criterion | The regex matches "`tests:` entries, when present" (`.` matches the backtick). The list ends at line 23 and `## Task spec` is at 88. | VERIFIED. It prints nothing on today's file, as expected before the edit. |
| `rg -c '^Named tests:$'` prints 1 after the edit | criterion | No `Named tests` text exists in the file today. After the edit only the rendering line matches: the `## Named tests` heading and the prose "lists `Named tests:`," do not match the anchored pattern. | VERIFIED (design check) |
| `rg -c 'YAML block has a .tests:'` prints nothing | criterion | The phrase is absent today and absent from the new section text at plan:1076. | VERIFIED. It also passes today, so it is trivially true. |
| "the Task spec above" | new section text, plan:1076 | The section goes "right before ## Your output" (plan:1071). In the template, `## Your output` is at line 66 and `## Task spec` at 88. | CONTRADICTED (see finding 1) |
| Before tree keeps the task's finished test file | new not-red case, ok-absent rewrite | plan:662-666 (step 6): only paths that are not the `<file>` of a `tests:` line are reverted. | VERIFIED. The rewritten text agrees with step 6. |

### Findings

- **DEFERRED** · The new `## Named tests` section points at "the Task spec above", but the section is placed before the Task spec.
  - Artifact text: "If the Task spec above lists `Named tests:`, each entry is `<file> :: <case>`." (plan:1076), with "a new section right before "## Your output"" (plan:1071).
  - Evidence: skills/executing-dag-plans/implementer-prompt.md:66 `## Your output`, :88 `## Task spec`. The task's own criterion requires the section's heading line to be less than that of `^## Your output`. So in the rendered prompt the Task spec is below the section.
  - Concrete failure: the sentence tells the reader to look somewhere other than where the list sits. An LLM implementer finds the list anyway, so nothing is built wrong. The plan states a false positional fact about the file it edits.
  - Resolution: say "below" or "in the Task spec section". Wording only, so DEFERRED.

- **DEFERRED** · The EU1 repository run writes the `tests:` declaration in flow form, which the frozen spec rejects, and the new entry now contains `: `.
  - Artifact text: "`tests: [tests/plan-state/plan-state.test.sh :: round on "2" writes review_rounds: 3]`" (EU1 bullet).
  - Evidence: spec:70-72, "Block form only ... Any value on the `tests:` line itself (`tests: [...]`, or a scalar) is a rule 16 violation". An implementer who copies the bracket form into the `.scratch/` plan gets a plan-state error, not `ok`.
  - Concrete failure: the one-off run could fail on its setup instead of reaching the check. The bracket form is shorthand and the same notation was in round 1, so it is likely to be read as shorthand.
  - Resolution: add "(written in block form, one `  - ` line per entry)" to the EU1 sentence.

### Checked, no finding
- B1 fix: the new case name exists and is unique. It was added in 76ed77d. It really fails at 76ed77d^ with the finished test file and prints a fail line that classifies as `ok` (one line, `FAIL: <case> (`). The after-tree pass is the same commit's own test, which I did not re-run. The suite run took the ordinary one-run time and I ran it once.
- B2 fix: git behaves as the plan now says. `prune` keeps a registration while the directory exists and drops it once the directory is gone. Deleting the leaked `mktemp -d` directory, which holds both `after` and `before`, is enough for one `prune` to clear both.
- B3 fix: the cited `:19` line and the "MUST receive" list exist as described. The `Task spec` / `depends_on:` / `### Body` anchors exist. The three rg criteria behave as claimed on the post-edit file: they print nothing or fail today, which is correct for a pre-change state. `{task.tests}` follows the same controller-substituted style as `{task.files}` (implementer-prompt.md:92).
- B4 fix: the new case contradicts nothing in step 6. A file kept at HEAD, with base code under it, is the exact scenario the case describes. The rewritten ok-absent text is consistent with step 6 and with the existing "before tree deletes a path new since base" case.
- Pre-existing "uses the ok-absent example `it exits at its first line`": the default `test_command` is `bash {file}` (spec:~97), where a missing `source` target does not stop a script by itself. The example says the suite "exits", so I take it as an explicit exit. No finding.

### Probes run (all outside the repository)
- A temp repo from `mktemp -d`, to test `git worktree prune` with and without the worktree directory. It was left in the system temp dir and holds nothing of the repo.
- A temp dir with `git show 76ed77d^:skills/writing-dag-plans/plan-state`, HEAD's test file, and a copy of `docs/superpowers/plans` (without `.audit`), for one suite run. It was removed afterwards. Nothing was created inside the repository.

### Out of lens
- Verifiability: `rg -c 'YAML block has a .tests:' ... prints nothing` already holds on today's file, so it cannot fail before the edit.
