# Design: pre-dispatch checks and a review-round cap

Date: 2026-11-12. Status: draft for gate 1.
Backlog: E5 (generic part) in `docs/proposals/2026-11-12-charters-and-waves-backlog.md`, and
the review-loop gap found in the 2026-11-12 smoke runs.

## Why

**Pre-dispatch checks.** Some plan defects are found by people or by gate-2 lenses that a
script could find for nothing. Two examples:

- In the 2026-11-12 smoke run, task-rename's text said "Rename the function `greet` to
  `say_hello` in `lib/greet.sh`" and its acceptance check read `lib/greet.sh`. But its
  `files:` held only `docs/usage.md`. `plan-state check` passed the plan, because it
  compares `files:` lists with each other and never reads task text. The defect surfaced
  only when two implementers, one after the other, reported BLOCKED. Preflight reports this
  case as a P1 warning, not an error: the file exists, so nothing proves the plan wrong.
- In one consuming repo, the largest class of gate-2 findings was a task needing a file no
  task declared, and 18 citations went stale between the last audit and the first dispatch.

**Review-round cap.** When a reviewer reports ISSUES, the executor re-dispatches the
implementer, then reviews again. Nothing bounds that loop. An implementer and a reviewer
that disagree can loop until the session runs out of money, and an unattended run has no
person to stop it.

## Goals

1. `plan-state preflight <plan>` finds four classes of defect in the text of a plan's
   unfinished tasks, and reports each with the task id, the path and the reason.
2. The planner runs it on a draft, the updater runs it on every edit to a task's text,
   `files:` or `depends_on:`, and the executor runs it at every start and resume, before it
   dispatches anything.
3. A task whose review returns ISSUES after its third fix round is marked `failed`, and the
   failure cascades as any other failure does.
4. The count of fix rounds survives a controller restart.

## Non-goals

- Checks specific to one repo (migration numbers, framework conventions). The plugin stays
  generic.
- Fixing a plan automatically. Preflight reports; the author fixes.
- Changing gate-2 lenses or merging any lens. That decision waits for data.
- Changing how BLOCKED retries work. The cap counts review ISSUES only.

## Anti-goals

- Noise. A check that fires on ordinary plans will be ignored. Every error must be a defect
  in the plan as written; anything less certain is a warning. This is why P3 is an error
  only for a line citation (see the table below).
- Changing what plan-state's existing commands print for a plan that has no
  `review_rounds` field. The cap is the one deliberate change in a run's behaviour, and it
  applies to every plan, since a missing field counts as 0. A plan on which preflight
  reports nothing otherwise runs exactly as it does today.

## Pre-dispatch checks

### Which text is read

A task's **text** is everything after its YAML block, up to the next `## Task:` heading or
the first H1 or H2 heading that is not `## Implementation`, `## Contracts` or
`## Acceptance criteria`. A plan-level `## Acceptance criteria` placed directly after the
last task is therefore read as part of that task; under the levels below that costs
warnings at most.

Preflight judges the text of `pending` and `ready` tasks only. A task that is running,
done, failed or skipped can no longer be edited, so a finding against it could never be
cleared. Every task's `files:` still counts as a declaration, whatever its status.

### What counts as a path

Candidates come from two places in a task's text, and nowhere else:

- in prose, each backticked span;
- in a fenced code block, each word, after splitting on whitespace and on quotes. So
  `grep -q x lib/greet.sh` yields `lib/greet.sh`.

Bare prose outside backticks is never read. Each candidate is then normalized: trailing
`.`, `,`, `;`, `:` and `)` are stripped; a line suffix `:N` or `:N-M` is split off and
kept; a leading `./` is stripped.

A normalized candidate is a **path** when it either contains `/` and its last segment ends
in an extension (`.` followed by letters, digits or `_`), or equals exactly an entry in
some task's `files:`. A candidate is never a path when it contains `*`, `?`, `<`, `>` or
`{`, is a URL, is absolute, or starts with `../`.

This is the token rule of `skills/auditing-artifacts/resolve-declared-paths` (its
backticked-token loop), widened to code-block words and to exact `files:` matches.
plan-state carries its own copy rather than calling that script, so plan-state stays one
script with no runtime dependency on another skill. One difference is deliberate:
`resolve-declared-paths` resolves `./` against the document, because it audits documents
that cite their siblings; preflight resolves every path against the repo root, because a
plan's tasks describe the repo, not the plan's own directory.

The repo root is the git top level of the directory holding the plan, as rules 11 and 13
already use. A path **exists** when a file or a directory is at it in the working tree.

### The four checks

| Id | Level | Fires when | Message |
|---|---|---|---|
| P1 | warning | A path appears on the same line as, and after, an edit verb (`edit`, `modify`, `change`, `update`, `rename`, `delete`, `remove`, `replace`, `rewrite`, `add to`, `append to`; any case and tense), and the path is not in this task's `files:`. | `<id> says to edit <path>, which is not in its files:` |
| P2 | error, or warning | A path does not exist, some other task declares it in `files:`, and no task that declares it is this task or one of its ancestors. It is a warning when every declarer is a descendant of this task, since depending on a descendant would make a cycle; otherwise an error. | `<id> uses <path>, which <other id> declares, but does not depend on <other id>` |
| P3 | error, or warning | A path does not exist and no task declares it. It is an error only for a line citation; without one it is a warning. A line citation is also an error when the path exists but is a directory, when the file has fewer lines than the larger of N and M, or when the suffix is `:0` or has M below N. | `<id> cites <path>, which does not exist and no task creates` / `<id> cites <path>:<N>, past the end of the file (<L> lines)` |
| P4 | warning | A path exists, another task that is `pending`, `ready` or `running` declares it, the two tasks have no dependency path between them, and the path is not in this task's `files:`. | `<id> reads <path> while <other id>, which can run at the same time, changes it` |

A path in a task's own `files:` never triggers P2, P3 or P4 for that task. Where a message
names another task, it names the first qualifying one in plan file order. Each (task, path,
check) is reported once; paths are compared without their line suffix. The finding takes
the highest level any of its citations reaches, and the report shows the first citation at
that level.

The trade-off in P3 is accepted: a task that names, without a line number, a file no task
declares is only a warning. A test fixture path or an example in prose looks exactly like
that, and an error on it would refuse correct plans.

Preflight does not replace `plan-quality.md`'s H8, which is unchanged and still refuses
undeclared imports. Preflight reads path tokens, H8 reads import statements, and a path
both flag may be reported by both.

### Command

`plan-state preflight <plan>`:

- prints one line per finding, `plan-state: preflight: P<n>: <message>`, warnings with
  `warning:` before the message, in task file order, then by each path's first appearance
  in that task, then by check id;
- exits 0 when there are no errors (warnings may print), 1 when there is at least one
  error, 2 on a usage error, as the other commands do;
- runs `check` first and, if `check` fails, prints its violations and exits 1 without
  running the four checks, since a broken graph makes "ancestor" meaningless.

### Where it runs

- **writing-dag-plans:** after step 6 (`check`) on the draft, where every task is
  `pending`. An error refuses the draft, as a `check` violation does. Warnings join the
  soft-heuristic warnings and the author confirms or revises.
- **executing-dag-plans:** on every invocation, at start and on resume. On resume it runs
  after `running` tasks are reset to `ready` and before the first dispatch. It is one more
  item in the existing "Pre-flight check" paragraph of `executing-dag-plans/SKILL.md`, not
  a separate step. An error halts the run before any dispatch and prints the findings; no
  task changes status. Warnings are printed and the run proceeds, because an unattended run
  has no one to ask.
- **updating-dag-plans:** on the edited copy, after `check`, for every operation that
  changes a task's body, `files:` or `depends_on:`, or removes a task. That includes Modify
  body, whose "No re-validation needed" gains this exception. Preflight also runs on the
  plan as it was before the edit. An error on the copy refuses the update when it is on a
  task the operation changed, or when the plan before the edit did not have it as an error,
  matched on (task, path, check). If the plan before the edit fails `check`, every error on
  the copy counts as new. Other errors, and all warnings, are shown with step 6's soft
  warnings under its "save anyway? (y/N)" prompt.

## Review-round cap

- A **fix round** is one re-dispatch of the implementer in response to an ISSUES verdict,
  from any reviewer: spec, quality, or merged. A reviewer re-run because its report had no
  single verdict line is not a fix round, and neither is the fresh dispatch of a `running`
  task after a restart.
- Each task carries an optional field `review_rounds: <n>`, the number of fix rounds so
  far. Absent means 0.
- `plan-state` owns the counter and the cap, as it owns statuses. A new command takes one
  task:
  - on a task that is not `running` it exits 2, whatever the value; this is checked first;
  - on a `running` task whose `review_rounds` is below 3 (absent counts as 0), it writes
    n+1, prints the new value alone on one line, and exits 0. When the field is absent it
    inserts `review_rounds: 1` on the line after `status:`, with the same line ending as
    that line;
  - at 3 it writes nothing, prints `plan-state: <id>: review cap reached (3 fix rounds)`
    and exits 1. Exit 1 means only this;
  - any other failure exits 2: a value that is not a whole number from 0 to 3, a usage
    error, and any failure to write the plan, which the command maps to 2 itself rather
    than taking the shell's status.
- `check` gains rule 15: `review_rounds`, when present, is a whole number from 0 to 3. The
  command and rule 15 read the cap from one value in plan-state. The controller never reads
  or compares the count. On every ISSUES verdict it calls the command:
  - exit 0: re-dispatch the implementer as today;
  - exit 1: `plan-state set <plan> <id> failed`, which cascades to downstream tasks as any
    failure does, and report the line the command printed as the reason in the final
    report, the same way as "reviewer gave no single verdict". The reason is not stored in
    the plan;
  - exit 2: halt.
- So an implementer gets at most 3 fix attempts across all of a task's reviews, and the
  fourth ISSUES verdict on a task fails it.
- **Restart.** `set` rewrites only the status line, so the count survives the resume reset
  of `running` to `ready`. A crash between the increment and the re-dispatch uses up that
  round. A task at 3 that is reset and dispatched again fails on its next ISSUES verdict.
- **No reset.** Nothing lowers the count, including Modify body. A hand-written draft may
  carry any value from 0 to 3.
- The executor's ISSUES handling, its status table, and the reviewer re-dispatch notes say
  the above in the executor skill and the implementer prompt.
- `plan-format.md` documents the field and rule 15, and its two rule-range statements
  ("Rules #7–#14 use the same refusal-message format" and "enforces rules 1–5 and 7–14")
  become 7–15 and 1–5 and 7–15. In `plan-state`'s header, the `check` usage line reads
  "rules 1-5 and 7-15", and the exit-code line says 1 also means "cap reached" for the new
  command. The README mentions the cap.

## Constraints

- POSIX sh and awk, passing under dash, bash, gawk, mawk and busybox awk, per `CLAUDE.md`.
- Every existing `plan-state` test still passes; new behaviour has tests in
  `tests/plan-state/plan-state.test.sh`, including:
  - on the two plans that pass `check` today
    (`docs/superpowers/plans/2026-08-27-seams-and-ground-truth-dag.md` and
    `docs/superpowers/plans/2026-11-12-d1-prerequisites-dag.md`), preflight writes nothing
    to stderr, and if it exits 1 it has printed at least one `preflight: P` line;
  - a fixture plan whose task text holds `and/or`, `7/7`, `missing/extra`, a backticked path
    ending a sentence, and an absent fixture path inside a code block yields no error; in
    the same run a second fixture yields a P3 error for an absent `path:N` and a P2 error
    for an absent path that a non-ancestor task declares, and one task that cites an
    absent, undeclared path first bare and then as `path:N` yields exactly one P3 line, an
    error;
  - the increment command with the field absent, at `review_rounds: 0`, 2 and 3, on a task
    that is not `running` (including one at 3), on a value of 4, on a CRLF plan where the
    inserted line keeps CRLF, and on a plan it cannot write, which exits 2 and leaves the
    file unchanged.
- `plan-state` stays one script.

## Left to the builder

- The name of the increment command.
- Message wording beyond the shapes in the table.
- How P1 matches an edit verb's tenses, and whether it skips a negated verb ("do not
  edit"). P1 is a warning, so a miss or an extra match costs a line of output.

## Audit record

- **2026-11-12** · rev `244dfbbf78e1` · commit `ba1e0e4` · lenses: absence, ambiguity,
  grounding, charter, coherence, design (6/6 ran) · **NOT READY — 4 blocking**
  - B1: the path rule turns ordinary task text (trailing punctuation, fixture paths) into
    P3 errors on plans `check` accepts → J1.
  - B2: on resume, preflight judges `done` tasks the updater cannot edit, so a run can be
    neither resumed nor updated → J2.
  - B3: P2 fires when a descendant also declares the path, on plans rule 4 accepts, and
    its message proposes a cycle → J2.
  - B4: the increment command is unbounded and no command reports the count; at 3 it
    writes 4, and rule 15 then halts the whole run instead of failing one task → J3.
  - Deferred, open: D1–D19 (see `.audit/…/reconciliation.md`).
  - Unverifiable: whether P1 catches the smoke-run defect (plan not in repo); the
    18-stale-citations figure (from another context).
- **2026-11-12** · rev `2208bb6f2317` · commit `ba1e0e4` + uncommitted J1–J3 edit · lenses:
  absence, ambiguity, grounding, charter, coherence, design (6/6 ran, diff-scoped; the
  J1–J3 edit rewrote every section but Why and Non-goals, so every lens's concern was in
  the diff) · **NOT READY — 4 blocking**
  - B1–B4 from round 1: fixes hold.
  - R2-B1: an update can create an error on a task it did not touch; the updater only
    warns and the executor's per-tick `check` does not run preflight → J4.
  - R2-B2: dedup on (task, path, check) ignores level, so a bare citation's warning hides
    a later `path:N` error → J5.
  - R2-B3: "H8 keeps only its classification" drops H8's refusal of undeclared imports,
    which preflight's token rule cannot see → J6.
  - R2-B4: the increment command's exit 1 means both "cap reached" and, under bash, a
    failed write, and the controller answers it with an irreversible `set failed` → J7.
  - Growth: 142 → ~209 lines, blocking 4 → 4, all four in text round 1's fixes wrote.
    Reconciler recommends applying J4–J7 and moving to planning without a round 3.
  - Deferred, open: R2-D1–R2-D18, round-1 D14, D19. Empirical unknown EU1: whether an
    unwritable-plan test can fail a write under root on CI.
- **2026-11-12** · rev `d479db07c4ad` · lenses: none — NOT YET RE-AUDITED · J4–J7 from the
  round-2 reconciliation applied as written. No round 3, by the author's choice: the
  blocking count held at 4 while the spec grew, and the reconciler judged R2-B2 and R2-B4
  better settled by tests than by prose. Carry into the plan's acceptance criteria for the
  task owning `tests/plan-state/plan-state.test.sh`: J9 (run the two real plans on temp
  copies with `done` rewritten to `pending`, since every task in both is `done` and the
  Constraints test reads no task text as written) and EU1 (whether the unwritable-plan
  test can fail a write under root on CI). Open: J8, J10, R2-D1–R2-D18, D14, D19.
