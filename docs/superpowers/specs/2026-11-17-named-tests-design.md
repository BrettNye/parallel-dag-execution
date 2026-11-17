# Design: acceptance criteria as named tests (E3)

Date: 2026-11-17. Status: approved by Brett, 2026-11-17; gate 1 next.
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
  - **Block form only**, one entry per `  - ` line. Any value on the `tests:` line itself
    (`tests: [...]`, or a scalar) is a rule 16 violation, because case names may contain commas.
    A trailing comment on the `tests:` line is not a value (the key line is comment-stripped,
    as for every key); only the entries are read literally.
  - **The raw entry** is the text after the `-` and the whitespace that follows it, taken
    literally to the end of the line, with trailing whitespace and a trailing CR removed. Unlike
    `files:` items, nothing is treated as a comment (` #` is part of the text), quotes are not
    stripped, and commas don't split it. Messages that quote `<entry>` quote the raw entry.
  - The raw entry is split at the first ` :: ` (space, two colons, space).
  - **`<file>`** is the part before it, trimmed at both ends, with every leading `./` removed
    (as for `files:` paths). It is a path relative to the repository root.
  - **`<case>`** is the part after it, trimmed at both ends. It is the case's name exactly as the
    suite prints it.
  - Two entries are **the same** when their `(<file>, <case>)` pairs are equal after this
    normalisation, so `./a.sh :: x` repeats `a.sh :: x`. All output uses the normalised pair.
  - A named case must be **unique in its file**: no other case in that suite prints the same
    name. `plan-state` cannot check this (it never reads the suite); `verify-tests` reports a
    breach as `ambiguous` (below), and `writing-dag-plans` tells authors to rename a duplicate.
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

- Values are read as other frontmatter values are: comment-stripped, then unquoted. Quote a
  prefix to keep its trailing space, as the defaults do.
- Every `{file}` in `test_command` is replaced by the entry's `<file>`, single-quoted for the
  shell. The result runs as `sh -c '<command>'` from the tree's root, with standard input from
  `/dev/null`. `verify-tests` sets no timeout of its own; the controller bounds it (see The
  executor).

**Matching output lines.** This is the only rule for reading a suite's output:
1. Each output line is normalised: a trailing CR and trailing whitespace are removed, then
   leading whitespace.
2. A **pass line** for `<case>` equals `test_pass_prefix` followed by `<case>`, exactly.
3. A **fail line** for `<case>` equals `test_fail_prefix` followed by `<case>`, or starts with
   `test_fail_prefix` followed by `<case>` followed by ` (` (space, open parenthesis). That is
   the form `plan-state.test.sh`'s `chk`, `has` and `hasnt` helpers print
   (`  FAIL: <name> (expected ...)`), and it keeps `exit 0` apart from `exit 0 with charter`.
4. A pass line or a fail line for a case is a **result line** for it. In one run, a case is:
   - **passed:** exactly one result line, and it is a pass line;
   - **failed:** exactly one result line, and it is a fail line;
   - **absent:** no result line;
   - **ambiguous:** two or more result lines.
5. Exit codes and all other lines are ignored.

A case whose name contains ` (` can still be matched by another case's fail line. That is
accepted: it is narrow, and the uniqueness rule above already asks authors to avoid it.

### Validation rules (new, enforced by `plan-state check`)

**16. `tests:` entries and the plan-level test fields.** Each of these is one violation line,
and `check` exits 1. `check` and `plan-state tests` use one shared predicate for them.
- an entry that does not split into a non-empty `<file>` and a non-empty `<case>`:
  `plan-state: rule 16: <id> tests entry "<entry>" is not "<file> :: <case>"`
- an entry whose `<file>` is not in the same task's `files:` (both normalised). The task writes
  its own cases, so the file is in scope. Line:
  `plan-state: rule 16: <id> test file <file> is not in its files:`
- an entry the same as an earlier entry in the task (see "the same", above), once per repeat:
  `plan-state: rule 16: <id> tests entry "<entry>" is repeated`
- a value on the `tests:` line: `plan-state: rule 16: <id> tests must be a block list`
- a plan-level `test_command` with no `{file}`:
  `plan-state: rule 16: test_command has no {file}`
- an empty plan-level `test_pass_prefix` or `test_fail_prefix`:
  `plan-state: rule 16: test_pass_prefix is empty` (or `test_fail_prefix`)

A fail prefix that begins the pass prefix's line, or the reverse, could confuse the two. This is
left to the plan author; the defaults don't overlap.

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
  So when git fails, a task with no `tests:` moves exactly as it does now.
- No other status writes or changes `base_sha:`.

**`plan-state tests <plan> <id>`** (new) prints everything `verify-tests` needs, so `plan-state`
stays the only plan parser. On stdout, in this order:

```
base <base_sha, or - when absent>
command <test_command>
pass <test_pass_prefix>
fail <test_fail_prefix>
file <path>
test <file>\t<case>
```

- `command`, `pass` and `fail` carry the plan-level values with the defaults applied. Each
  value runs from after the single space following the keyword to the end of the line,
  untrimmed, so `pass PASS: ` ends in a space.
- There is one `file` line per item of the task's `files:`, normalised as `plan-state` already
  normalises them (unquoted, comment-stripped, leading `./` removed, inline lists split), in
  order. A task with no `files:` has no `file` lines.
- There is one `test` line per entry, in `tests:` order, with the normalised `<file>` and
  `<case>` and a tab between them. A task with no `tests:` has no `test` lines.
- Exit codes:
  - 0: printed.
  - 2, with nothing on stdout. The checks run in this order, and the first group that fails is
    the only one reported:
    1. fewer than two arguments: the usage text on stderr, as for every other subcommand;
    2. the plan cannot be read (missing, a directory, or unreadable):
       `plan-state: cannot read <plan>`, as for every other subcommand;
    3. not exactly one id after the plan: the usage text on stderr;
    4. the id is unknown (`plan-state: no task with id <id>`) or not unique
       (`plan-state: id <id> is not unique; run: plan-state check`);
    5. a plan-level rule 16 check fails: every failing plan-level rule 16 line, in the order
       rule 16 lists them, exactly as `check` prints them, on stderr;
    6. this task fails any of rule 16's task-level checks (an entry check, or a value on its
       `tests:` line): `plan-state: <id> has a bad tests entry; run: plan-state check`.
    Other tasks' entries don't affect it.
- The script header gains a `tests` line, `check`'s line becomes "validate rules 1-5 and 7-17"
  (ASCII hyphen), and `usage()` prints the whole header through its `# Exit:` line. The existing
  usage assertion in `tests/plan-state/plan-state.test.sh` is updated to match.

## `verify-tests` (new helper)

`skills/executing-dag-plans/verify-tests`, in POSIX sh and awk like the other helpers, beside
`git-commit-safe`.

**Usage:** `verify-tests <plan> <id>`. The repository is the one the plan is in
(`git -C <plan's directory> rev-parse --show-toplevel`). It is looked up only after steps 1-3,
so a plan outside a repository whose task has no `tests:` still gets step 2's exit 0.

**What it does:**
1. Runs `plan-state tests <plan> <id>` (the `plan-state` beside it in the plugin, at
   `../writing-dag-plans/plan-state`) and reads everything from its output; it never opens the
   plan itself. When `plan-state tests` exits 2, `verify-tests` relays its stderr and exits 2.
   The task's status doesn't matter: any task with a `base_sha:` can be checked.
2. With no `test` lines, it prints `verify-tests: <id>: no named tests` on stdout and exits 0.
3. With `base -`, it prints `verify-tests: <id>: no base_sha (set the task running first)` on
   stderr and exits 2.
4. It runs `git worktree prune` in the repository, to clear registrations left by an earlier run
   that was killed. It resolves `HEAD` to one commit SHA once, and builds both trees below from
   that SHA. From here on it traps INT, TERM and HUP. The trap does step 9, prints
   `verify-tests: <id>: interrupted` on stderr, and exits 2, whatever step it interrupted.
5. **After tree:** a detached worktree at that SHA, in a fresh directory made with
   `mktemp -d` (so under `${TMPDIR:-/tmp}`). Only committed work counts: uncommitted changes in
   the shared working tree are ignored.
6. **Before tree:** another detached worktree at that SHA. Every `file` path that is not a
   `<file>` of one of the task's `test` lines is put back to its content at `base_sha`. A path
   that did not exist at `base_sha` is deleted. So the before tree has the task's finished tests
   and everyone else's work, but this task's code as it was when the task started.
7. In each tree, it runs each distinct `<file>` once, as described under `test_command`, with
   standard output and standard error captured together. A file that does not exist in a tree
   counts as a run with no output.
8. For each entry, in order, it classifies the case in each tree as passed, failed, absent or
   ambiguous (Matching output lines, above), and gives the entry one label. The first that
   applies wins:
   1. **`ambiguous`:** the case is ambiguous in either tree.
   2. **`not-green`:** the case did not pass in the after tree.
   3. **`not-red`:** the case passed in the before tree.
   4. **`ok-absent`:** the case was absent in the before tree (red by absence). Absence is still
      red: a suite for a brand-new script often stops at its first line when the script is
      missing. It is reported apart because it can also mean the before run broke for an
      unrelated reason, such as a deleted fixture.
   5. **`ok`:** the case failed in the before tree (red by failure).
9. It removes both worktrees (so `git worktree list` shows neither) and the temporary
   directory, on success, on failure, and on INT, TERM or HUP.

**Output, on stdout:** one line per entry, in `tests:` order, then a total line, then the
output tails.

```
ok<TAB><file><TAB><case>          failed before (fail line), passed after
ok-absent<TAB><file><TAB><case>   no result line before, passed after
not-red<TAB><file><TAB><case>     passed before the task's change
not-green<TAB><file><TAB><case>   did not pass after it
ambiguous<TAB><file><TAB><case>   two or more result lines in a run (the name is not unique)
verify-tests: <id>: <n> ok, <m> failed
```

- `ok` and `ok-absent` count as ok; `not-red`, `not-green` and `ambiguous` count as failed, in
  the total and for the exit code.
- **Tails,** after the total line. They follow the printed label, not the underlying
  properties:
  - a file with a `not-green` or `ambiguous` entry gets an **after block**: the header
    `--- <file> (after)`, then the last 20 lines of its after-tree output, each prefixed with
    `  | `;
  - a file with a `not-red` or `ok-absent` entry gets a **before block**: the header
    `--- <file> (before)`, then the last 20 lines of its before-tree output, prefixed the same
    way;
  - so an entry that is both not-red and not-green prints `not-green` and gives only an after
    block;
  - files go in the order they first appear in `tests:`, and each file prints its after block
    (if any) and then its before block (if any) before the next file starts;
  - a run with no output shows the single line `  | (no output)`.

For example, with `a.sh :: x` absent before and passing after, and `b.sh :: y` failing after:

```
ok-absent	a.sh	x
not-green	b.sh	y
verify-tests: T3: 1 ok, 1 failed
--- a.sh (before)
  | ...
--- b.sh (after)
  | ...
```

**Exit codes:**
- 0: every entry is ok, or there are no entries.
- 1: at least one entry failed.
- 2: a usage error, a `plan-state tests` error, no `base_sha`, or a git failure (the worktree
  could not be made, or `base_sha` is not a commit), or an interrupt (INT, TERM or HUP) from
  step 4 on. The reason goes on stderr. Stderr may also carry git's own lines (for example from
  `git worktree add`); only the messages this spec names are pinned, so a test checks that
  stderr contains them, not that it equals them.

**It never:** writes to the plan, touches the shared working tree or index, or commits.

## The executor

**Mark running before dispatch.** In `SKILL.md` step 4, the controller runs
`plan-state set <plan> <id> running` *before* the Agent dispatch, for every task, not after it.
Otherwise a foreground harness records `base_sha` after the implementer has committed, and every
case reads `not-red`. When `set` exits 2, the controller halts and does not dispatch. If a
dispatch then fails, the task stays `running` with no subagent until the next resume resets it
to `ready`; that is safer than today's opposite case, a subagent working on a task still marked
`ready`.

After an implementer reports DONE or DONE_WITH_CONCERNS, and before any review, the controller
runs `verify-tests <plan> <id>`, by its path under the plugin root as it runs `plan-state`, with
an explicit Bash tool timeout of 600000 ms, in the foreground. A plan-state suite takes about
85 s per run here and the check runs it twice, so the default 120 s limit is too short. A run
that ends without exit 0, 1 or 2 (killed by the timeout, or interrupted) counts as exit 2. This
is a deliberate trade-off: an implementer's code that loops forever halts the run as a tooling
fault rather than costing one fix round, which is safe and visible, and the user decides from
there.

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
  naming the case the task will write. The name must be unique in its file; if the suite
  already has a case by that name (this repo's suites repeat `exit 0`), pick another name or
  have the task rename the existing one.
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

## Audit record

- **2026-11-17** · rev `368c26407605` · commit `0ca8f33` · lenses: absence, ambiguity, grounding, charter,
  coherence, design (6/6 ran) · **NOT READY — 9 blocking**
  - Blocking: B1 base_sha taken after dispatch; B2 check outlasts the 120 s tool limit, no
    outcome or cleanup for a killed run; B3 fail-line rule stated three ways; B4 repeated case
    names; B5 tail order across files; B6 tail for a not-red and not-green case; B7 usage text
    vs plan-state usage(); B8 entry normalisation and identity; B9 plan-state tests omits what
    verify-tests needs.
  - Joint resolutions proposed: J1 (B3, B4), J2 (B5, B6), J3 (B7, B8, B9), J4 (B1, B2). Not
    applied.
  - Empirical unknown: a fresh worktree lacks untracked or ignored dependencies; becomes an
    acceptance criterion on the E3 plan's verify-tests task.
- **2026-11-17** · rev `b972896a3a37` · commit `d218d29` · lenses: absence, ambiguity, grounding,
  coherence, design (5/5 ran; carried: charter — the diff touched no convention or placement
  claim beyond the plan-state usage header, which grounding covered) · **NOT READY — 4 blocking**
  - J1-J4 from round 1 applied; B1-B9 resolved.
  - Blocking: B1 interrupt trap has no exit status; B2 a value on the `tests:` line has two
    readings for `plan-state tests`; B3 stderr content and order when several exit-2 faults
    hold; B4 "(or in the background)" leaves verify-tests unbounded.
  - Joint resolutions proposed: J-A (B2, B3), J-B (B1), J-C (B4). Not applied.
  - Empirical unknown: which signal reaches verify-tests on a Bash tool timeout; becomes an
    acceptance criterion on the E3 plan's verify-tests task.
- **2026-11-17** · rev `e1ffd5e60e4b` · commit `348fb0e` · lenses: absence, ambiguity, coherence
  (3/3 ran; carried: grounding, design, charter — the ~10-line diff makes no new claim about
  existing code, changes no structure, touches no convention) · **NOT READY — 1 blocking**
  - Round 2's J-A, J-B, J-C applied; its B1-B4 resolved.
  - Blocking: B1 the ordered exit-2 list omits `plan-state: cannot read <plan>`, which
    plan-state checks (plan-state:25) before any subcommand's argument count.
  - Joint resolution proposed: J-D (reorder the list to match the code). Not applied.
  - Deferred: D1 trap exit on a second signal or failed cleanup (plan AC); D2 interrupt exit 2
    holds only from step 4; D3 whether stderr carries only the named messages.
