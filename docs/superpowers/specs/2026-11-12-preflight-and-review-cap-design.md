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
  only when two implementers, one after the other, reported BLOCKED.
- In one consuming repo, the largest class of gate-2 findings was a task needing a file no
  task declared, and 18 citations went stale between the last audit and the first dispatch.

**Review-round cap.** When a reviewer reports ISSUES, the executor re-dispatches the
implementer, then reviews again. Nothing bounds that loop. An implementer and a reviewer
that disagree can loop until the session runs out of money, and an unattended run has no
person to stop it.

## Goals

1. `plan-state preflight <plan>` finds four classes of defect in a plan's task text, and
   reports each with the task id, the path and the reason.
2. The planner runs it on a draft, and the executor runs it before its first dispatch.
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
  in the plan as written; anything less certain is a warning.
- Any change in behaviour for a plan that preflight finds clean, or for a plan without the
  new field.

## Pre-dispatch checks

### What counts as a path

A token in a task's text (its prose, acceptance criteria, and code blocks; everything
after the task's YAML block up to the next `## Task:` heading) is a **path** when it is
relative, has no spaces, and either:

- contains a `/` and has the shape `segment/segment[/...]`, where segments use letters,
  digits, `.`, `_` and `-`; or
- has no `/`, but names a file that exists at the repo root or appears in some task's
  `files:`.

A path may carry a line suffix, `path:N` or `path:N-M`. URLs, absolute paths, globs
(`*`) and paths containing `<` or `{` are not paths. Inside inline code and code blocks,
the text is split on whitespace and quotes, and each word is tested on its own, so
`grep -q x lib/greet.sh` yields `lib/greet.sh`.

The repo root is the git top level of the directory holding the plan, as rules 11 and 13
already use. Existence is checked against the working tree.

### The four checks

| Id | Level | Fires when | Message |
|---|---|---|---|
| P1 | warning | A path appears on the same line as, and after, an edit verb (`edit`, `modify`, `change`, `update`, `rename`, `delete`, `remove`, `replace`, `rewrite`, `add to`, `append to`; any case and tense), and the path is not in this task's `files:`. | `<id> says to edit <path>, which is not in its files:` |
| P2 | error | A path does not exist, is in another task's `files:`, and that task is not an ancestor of this one. | `<id> uses <path>, which <other id> creates, but does not depend on <other id>` |
| P3 | error | A path does not exist and is in no task's `files:`. For `path:N`, also when the file exists but has fewer than N lines. | `<id> cites <path>, which does not exist and no task creates` / `<id> cites <path>:<N>, past the end of the file (<L> lines)` |
| P4 | warning | A path exists, is in another task's `files:`, the two tasks have no dependency path between them, and the path is not in this task's `files:`. | `<id> reads <path> while <other id>, which can run at the same time, changes it` |

A path in a task's own `files:` never triggers P2, P3 or P4 for that task. Each
(task, path, check) is reported once.

### Command

`plan-state preflight <plan>`:

- prints one line per finding, `plan-state: preflight: P<n>: <message>`, warnings with
  `warning:` before the message;
- exits 0 when there are no errors (warnings may print), 1 when there is at least one
  error, 2 on a usage error, as the other commands do;
- runs `check` first and, if `check` fails, prints its violations and exits 1 without
  running the four checks, since a broken graph makes "ancestor" meaningless.

### Where it runs

- **writing-dag-plans:** after step 6 (`check`) on the draft. An error refuses the draft,
  as a `check` violation does. Warnings join the soft-heuristic warnings and the author
  confirms or revises.
- **executing-dag-plans:** once, before the first tick dispatches anything. An error halts
  the run before any dispatch and prints the findings; no task changes status. Warnings are
  printed and the run proceeds, because an unattended run has no one to ask.
- **updating-dag-plans:** after its structural validation, with the same rules as writing.

## Review-round cap

- A **fix round** is one re-dispatch of the implementer in response to an ISSUES verdict,
  from any reviewer: spec, quality, or merged. A reviewer re-run because its report had no
  single verdict line is not a fix round.
- Each task carries an optional field `review_rounds: <n>`, the number of fix rounds so
  far. Absent means 0.
- When a review returns ISSUES:
  - if the task's `review_rounds` is below 3, the controller increments it, then
    re-dispatches the implementer as today;
  - if it is already 3, the controller marks the task `failed` with the reason
    `review cap: ISSUES after 3 fix rounds`, and the failure cascades to its downstream
    tasks as usual.
- So an implementer gets at most 3 fix attempts across all of a task's reviews, and the
  fourth ISSUES verdict on a task fails it.
- `plan-state` owns the counter, as it owns statuses:
  - a new command increments `review_rounds` for one `running` task, writes it into that
    task's YAML block, and prints the new value. It refuses a task that is not `running`;
  - `check` gains rule 15: `review_rounds`, when present, is a whole number from 0 to 3.
- The executor's ISSUES handling, its status table, and the reviewer re-dispatch notes say
  the above in the executor skill and the implementer prompt.
- `plan-format.md` documents the field and rule 15, and the README mentions the cap.

## Constraints

- POSIX sh and awk, passing under dash, bash, gawk, mawk and busybox awk, per `CLAUDE.md`.
- Every existing `plan-state` test still passes; new behaviour has tests in
  `tests/plan-state/plan-state.test.sh`.
- Preflight on each of the repo's own plans under `docs/superpowers/plans/` exits 0 or 1,
  never 2 and never a crash. Findings there are expected: those plans have run, and the repo
  has moved on from the paths they cite.
- `plan-state` stays one script.

## Left to the builder

- The name of the increment command.
- How paths are extracted, within the definition above.
- Message wording beyond the shapes in the table.
- Whether preflight shares code with `resolve-declared-paths`.
