# Design: acceptance criteria as named tests (E3)

Date: 2026-11-17. Status: draft for Brett's review.
Backlog item: E3 in `docs/proposals/2026-11-12-charters-and-waves-backlog.md`.
Also the feature the D2 experiment builds (`2026-11-16-d2-gate2-ablation-design.md`). Its plan
should come out around 15 tasks, and this spec pins the two command interfaces exactly, because
a hidden functional suite is written from this spec alone.

## Why

Today a task's acceptance criteria are prose. The implementer reports its own RED-THEN-GREEN
evidence (`implementer-prompt.md`), and a spec reviewer model reads the report and judges whether
the criteria hold. Nothing checks that the failing test the implementer quotes exists, that it
failed before the change, or that it passes now.

Brett's rule is scripts for whatever has one right answer, and a model only for judgment. Whether
a named test case fails on the old code and passes on the new code has one right answer. E3 moves
that check into a script. The spec reviewer then judges only what needs judgment: whether each
named test really tests its criterion, plus any criteria that can't be tests. The gate-2
verifiability lens gets a mechanical anchor for the same reason.

## Goals

- A task can name the test cases that prove it, in its YAML block.
- A script decides, per named case, whether it was red before the task's change and green after.
- A failed check sends the implementer back, the same way a reviewer's ISSUES verdict does.
- The spec reviewer stops re-checking what the script already verified.

## Non-goals

- Test output formats other than one line per case that starts with a fixed prefix. The prefix
  is configurable; nothing else about the format is.
- Coverage or mutation testing: whether the named tests are good enough stays with the reviewer.
- Requiring every criterion to have a named test. Criteria that can't be tests stay prose.

## Anti-goals (a failure even if it works)

- The check touching the shared working tree, where other implementers are working at the same
  time.
- A case counted green when it never ran, or red because the suite crashed for another reason
  and the check didn't say so.
- The implementer running its own check. That is the party being checked.

## Approaches

Brett picked these on 2026-11-17:

- **What "failed first" means: named cases within a file (picked).** The other options were a
  whole test file (it can't tell which test proves which criterion) and checking the
  implementer's report (the weakest).
- **What a failed check does: works like a reviewer's ISSUES verdict (picked).** It uses a fix
  round against the cap of 3 and re-dispatches the implementer with the check's output. The
  other options were handing the output to the spec reviewer as evidence (that leaves the
  judgment with a model) and failing the task at once (one wrong case name kills a branch of
  the plan).
- **Where the code lives: `plan-state` parses, a new helper runs (picked).** The other options
  were all inside `plan-state` (a pure plan tool would start building worktrees and running
  project code) and the implementer running the check (rejected by the anti-goals above).

## The plan format

### Task fields

```yaml
tests:                          # OPTIONAL. The test cases that prove this task.
  - tests/plan-state/plan-state.test.sh :: round on "2" counts to 3
base_sha: 1f3c9e0a...           # Written by plan-state set ... running. Never hand-edited.
```

- **A `tests:` entry** is `<file> :: <case>`.
  - **Block form only**, one entry per `  - ` line. An inline `tests: [...]` is a rule 16
    violation, because case names may contain commas.
  - The entry is the text after `- `, taken literally to the end of the line. Only trailing
    whitespace and a trailing CR are removed. Unlike `files:` items, nothing is treated as a
    comment (` #` is part of the text), quotes are not stripped, and commas don't split it.
  - It is split at the first ` :: ` (space, two colons, space).
  - `<file>` is a path relative to the repository root. A leading `./` is removed, as for
    `files:` paths, in rule 16's scope check and in all output.
  - `<case>` is the case's name exactly as the suite prints it, with leading and trailing
    whitespace trimmed.
- **`base_sha:`** is the commit at `HEAD` of the plan's repository the first time the task is
  set `running`. It is written once and kept through every later status change, including a
  resume's reset of `running` to `ready` and the next `running`.
  Keeping the first value means a re-dispatched task's own earlier commits still count as "the
  task's change".

### Plan-level fields

```yaml
test_command: bash {file}       # OPTIONAL. Default: bash {file}. Run from the repository root.
test_pass_prefix: "PASS: "      # OPTIONAL. Default: "PASS: ".
test_fail_prefix: "FAIL: "      # OPTIONAL. Default: "FAIL: ".
```

- Every `{file}` in `test_command` is replaced by the entry's `<file>`, single-quoted for the
  shell. The result runs as `sh -c '<command>'` from the tree's root, with standard input from
  `/dev/null`. There is no timeout. A hanging suite hangs the check, and the executor's own
  limits bound that.
- A case **passed** in a run when some output line, with leading whitespace removed, equals
  `test_pass_prefix` followed by `<case>`, exactly. A case **failed** in a run when some line
  equals `test_fail_prefix` followed by `<case>`. For a fail line, everything after the case
  name is ignored, because this repository's suites print `  FAIL: <name> (expected ...)`. Exit
  codes and other lines are ignored.

### Validation rules (new, enforced by `plan-state check`)

**16. `tests:` entries.** Each of these is one violation line, and `check` exits 1:
- an entry that does not split into a non-empty `<file>` and a non-empty `<case>`:
  `plan-state: rule 16: <id> tests entry "<entry>" is not "<file> :: <case>"`
- an entry whose `<file>` is not in the same task's `files:`. The task writes its own cases, so
  the file is in scope. Line: `plan-state: rule 16: <id> test file <file> is not in its files:`
- the same entry twice in one task: `plan-state: rule 16: <id> tests entry "<entry>" is repeated`
- an inline list: `plan-state: rule 16: <id> tests must be a block list`
- a plan-level `test_command` with no `{file}`:
  `plan-state: rule 16: test_command has no {file}`
- an empty plan-level `test_pass_prefix` or `test_fail_prefix`:
  `plan-state: rule 16: test_pass_prefix is empty` (or `test_fail_prefix`)

A fail-prefix line for a case is matched as a prefix (`FAIL: <case>` then anything), so a fail
prefix that begins the pass prefix's line, or the reverse, could confuse the two. This is left
to the plan author; the defaults don't overlap.

**17. `base_sha:`.** When present, it must be 7 to 40 lowercase hex characters. Otherwise:
`plan-state: rule 17: <id> base_sha is <value>`.

## `plan-state` changes

**`plan-state set <plan> <id> running`** writes `base_sha: <sha>` on the line after `status:`
when the task has no `base_sha:`. `<sha>` is the full 40-character output of
`git -C <plan's directory> rev-parse HEAD`.
- The existing checks run first: an illegal move or an unknown id is refused exactly as today.
- When the task already has a `base_sha:`, git is not called and the field is left untouched.
- When `git` fails (no repository, or no commit yet):
  - a task **with** `tests:` entries is refused with exit 2, and nothing changes:
    `plan-state: refused <id>: cannot read HEAD for base_sha`;
  - a task **without** them is set `running` as today, with no `base_sha:` and no message.
  So a plan outside a repository, or with no `tests:`, behaves exactly as it does now.
- No other status writes or changes `base_sha:`.

**`plan-state tests <plan> <id>`** (new) prints, on stdout:

```
base <base_sha, or - when absent>
test <file>\t<case>
test <file>\t<case>
```

- There is one `test` line per entry, in `tests:` order, with a tab between file and case.
- With no `tests:`, it prints only the `base` line.
- Exit codes:
  - 0: printed.
  - 2: the usage is wrong (`plan-state: usage ...` on stderr), the id is unknown
    (`plan-state: no task with id <id>`), or the id is not unique
    (`plan-state: id <id> is not unique; run: plan-state check`).
- When any of this task's `tests:` entries breaks rule 16 (no ` :: `, an empty side, a
  repeat, a file outside `files:`, or an inline list), it prints nothing on stdout and exits 2
  with `plan-state: <id> has a bad tests entry; run: plan-state check`. Rule 16's other
  violations, and other tasks' entries, don't affect it.

## `verify-tests` (new helper)

`skills/executing-dag-plans/verify-tests`, in POSIX sh and awk like the other helpers, beside
`git-commit-safe`.

**Usage:** `verify-tests <plan> <id>`. The repository is the one the plan is in
(`git -C <plan's directory> rev-parse --show-toplevel`).

**What it does:**
1. Reads `plan-state tests <plan> <id>` and the plan-level `test_command`, `test_pass_prefix`
   and `test_fail_prefix`, using the defaults when absent. A `test_command` with no `{file}`,
   or an empty prefix, exits 2 with the rule 16 line. The task's status doesn't matter: any task
   with a `base_sha:` can be checked.
2. With no `tests:` entries, it prints `verify-tests: <id>: no named tests` and exits 0.
3. With no `base_sha`, it prints `verify-tests: <id>: no base_sha (set the task running first)`
   on stderr and exits 2.
4. **After tree:** a detached worktree at the repository's current `HEAD`, in a fresh temporary
   directory. Only committed work counts: uncommitted changes in the shared working tree are
   ignored.
5. **Before tree:** another detached worktree at `HEAD`. Every path in the task's `files:` that
   is not a `<file>` of one of its `tests:` entries is put back to its content at `base_sha`. A
   path that did not exist at `base_sha` is deleted. So the before tree has the task's finished
   tests and everyone else's work, but this task's code as it was when the task started.
6. In each tree, it runs each distinct `<file>` once, as described under `test_command`, with
   standard output and standard error captured together. A file that does not exist in a tree
   counts as a run with no output.
7. For each entry, in order, it decides:
   - **green:** the case passed in the after tree;
   - **red:** the case did not pass in the before tree. That is either **red by failure** (the
     before tree printed the case's fail line) or **red by absence** (it printed neither line).
     Absence is still red. A suite for a brand-new script often stops at its first line when
     the script is missing, and that is a genuine red. But absence is reported apart, because
     it can also mean the before run broke for an unrelated reason, such as a deleted fixture.
8. It removes both worktrees and the temporary directory, on success and on failure.

**Output, on stdout:** one line per entry, in `tests:` order, then a total line, then the
output tails.

```
ok<TAB><file><TAB><case>          failed before (fail line), passed after
ok-absent<TAB><file><TAB><case>   printed nothing before, passed after
not-red<TAB><file><TAB><case>     passed before the task's change
not-green<TAB><file><TAB><case>   did not pass after it
verify-tests: <id>: <n> ok, <m> failed
```

- A case that is both not-red and not-green prints `not-green`.
- `ok-absent` counts as ok, both in the total and for the exit code.
- **Tails,** after the total line. Files are listed in the order they first appear in `tests:`:
  - for each file with a `not-green` entry, a header `--- <file> (after)`, then the last 20
    lines of its after-tree output, each prefixed with `  | `;
  - for each file with an `ok-absent` or `not-red` entry, a header `--- <file> (before)`, then
    the last 20 lines of its before-tree output, prefixed the same way.
  - A run with no output shows the single line `  | (no output)`.
  - A file with both kinds gets its after block first.

**Exit codes:**
- 0: every entry is ok, or there are no entries.
- 1: at least one entry failed.
- 2: a usage error, no `base_sha`, a `plan-state tests` error, or a git failure (the worktree
  could not be made, or `base_sha` is not a commit). The reason goes on stderr.

**It never:** writes to the plan, touches the shared working tree or index, or commits.

## The executor

After an implementer reports DONE or DONE_WITH_CONCERNS, and before any review, the controller
runs `verify-tests <plan> <id>`:

- **Exit 0:** reviews proceed as today. The `verify-tests` output goes into the reviewers'
  prompts.
- **Exit 1:** it is a fix round, exactly as a reviewer's ISSUES verdict is. The controller runs
  `plan-state round <plan> <id>`:
  - round exit 0: it re-dispatches the implementer with the `verify-tests` output as the issue
    list, and runs `verify-tests` again after it reports;
  - round exit 1 (cap reached): it marks the task `failed`, giving the printed line as the
    reason;
  - round exit 2: it halts.
- **Exit 2:** it halts and prints the reason, as for `plan-state round` exit 2. A broken check is
  a tooling fault, not the implementer's.

`SKILL.md`'s review flow and its Review-round cap section gain this step. A fix round is now
"one re-dispatch of the implementer after an ISSUES verdict or a failed `verify-tests`".

## The prompts

- **Implementer** (`implementer-prompt.md`). When the task has `tests:`, say the following:
  each named case must exist in its file with exactly that name, must fail before the change and
  pass after, and is checked by a script from committed work. Commit before reporting. The
  RED-THEN-GREEN report stays, for criteria without named tests.
- **Spec reviewer and merged reviewer.** They receive the `verify-tests` output. For a criterion
  with a verified named test, they judge only whether that test really tests the criterion, and
  do not re-run or re-derive it. For an `ok-absent` entry, they also read its `(before)` tail
  and judge whether the case was red for the right reason. If it wasn't (the suite broke
  before reaching the case for some other cause), that is an ISSUES finding. Prose-only
  criteria are reviewed as today.
- **Quality reviewer.** No change.

## Writing and updating plans

- **`plan-format.md`:** document `tests:`, `base_sha:`, `test_command`, `test_pass_prefix`, `test_fail_prefix`, and
  rules 16 and 17. `plan-state check` now enforces rules 1–5 and 7–17.
- **`writing-dag-plans`:** for each acceptance criterion a test can check, add a `tests:` entry
  naming the case the task will write.
- **`plan-quality.md`:** a new soft heuristic, S17. It warns about a task whose acceptance
  criteria name a test-like check (a command to run, an expected output or exit code) but whose
  YAML block has no `tests:` entries.
- **`updating-dag-plans`:** it may edit `tests:` on pending and ready tasks, like any field. No
  operation writes or changes `base_sha:`, for the same reason as `review_rounds:`. Its preflight
  and check run as today.
- **Gate-2 `verifiability` lens** (`lenses-plan.md`): a criterion with a `tests:` entry is
  verifiable when the entry names a case the task's own text says it will write. Flag an entry
  whose case name appears nowhere in the task's text.

## Constraints

- POSIX sh and awk under dash and bash, and under gawk, mawk and busybox awk (the repository's
  `CLAUDE.md`).
- Each script has a suite under `tests/<suite>/`: `verify-tests` gets `tests/verify-tests/`, and
  the `plan-state` additions go in `tests/plan-state/`.
- `verify-tests` is extensionless, so it is listed in `.gitattributes`.
- Plans without `tests:` behave exactly as today. Their only change is that `base_sha:` appears
  on tasks when they run.

## Left to the builder

- Internal structure of `verify-tests` and of the new `plan-state` code.
- How the before tree restores files: `git checkout <base_sha> -- <path>` or equivalent.
- The wording of the prompt changes, within the rules above.
- S17's exact detection wording, as a soft heuristic.
