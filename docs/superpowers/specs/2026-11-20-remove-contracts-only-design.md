# Design: remove the contracts-only plan format, as the first real run of named tests

Date: 2026-11-20. Status: draft, for Brett's approval.

## Why

Two reasons, one change.

1. **The format lost.** The D1 pilot (`experiments/d1-no-implementation/REPORT.md`) tested plans
   whose tasks carry `## Contracts` and no `## Implementation`. It failed its decision rule, so the
   normal format stays. The experimental support it added still sits in the planner, the plan
   rules, the lenses and `plan-state`. Every planner and lens reads it, and nothing uses it.
2. **Named tests have never run for real.** E3 (`tests:` per task, `verify-tests` before review)
   is on PR #6. D2 built it but executed with an older pinned plugin, so no execution has gone
   through the new loop. On this repo one check took 606-1710 s. This change is a small, real
   plan whose tasks name cases in the slowest suite, `tests/plan-state/plan-state.test.sh`.

Brett chose removal over a warning label on 2026-11-20.

## Goals

- No trace of contracts-only remains in `skills/` or `tests/`, except rule 14's rejection of it.
- Execute this change through the plugin as PR #6 would ship it, and learn whether the named-test
  check is fast and reliable enough to stay on by default.

## Non-goals

- Editing D1's experiment files or plan snapshots under `experiments/`. They are history; nothing
  validates them.
- Changing `plan-state charter`. Its `## Contracts` table belongs to superspec charters, a
  different thing with the same word.
- Any change to verify-tests itself. This run measures it; a fix, if needed, comes after.

## The change

- **Rule 14 stays, narrowed.** `implementation:`, when present, must be `full`. A plan that sets
  `contracts-only` gets a violation naming it as removed after D1, for example
  `plan-state: rule 14: implementation is contracts-only (removed after the D1 pilot; use full)`.
  Any other value keeps today's message, `implementation is <value>`. Keeping the field means an
  old plan that says `full` still passes.
- **`plan-state`:** the per-task `## Contracts`/`## Implementation` checks under rule 14 go, and
  so does the `seccon` bookkeeping that only they use. `## Contracts` text that preflight reads
  (line 413 at HEAD) is left to the builder: remove it only if nothing but contracts-only plans
  has such a section.
- **Tests:** T21 in `tests/plan-state/plan-state.test.sh` is rewritten to pin the new rule:
  `full` passes; `contracts-only` exits 1 with the removal message; a bogus value exits 1 naming
  it; the rule holds under the alternate shell, as T21 does today.
- **Docs:** remove the contracts-only text from
  - `skills/writing-dag-plans/SKILL.md` (the `implementation:` bullet and the parenthetical in
    step 6.5),
  - `skills/writing-dag-plans/plan-format.md` (the frontmatter comment, the "Contracts-only
    plans" section and rule 14's text),
  - `skills/writing-dag-plans/plan-quality.md` (the "Contracts-only plans" paragraph),
  - `skills/auditing-artifacts/lenses-plan.md` (the "Contracts-only plans" section).
- All suites pass after the change, under dash and the three awks, as `CLAUDE.md` requires.

## How it runs (the trial)

- **Plan:** written with this plugin's `writing-dag-plans`, normal format, with `tests:` on every
  task that changes `plan-state` or its suite. Expected size 4-6 tasks.
- **Gate 2:** one round, then fix its blocking findings and execute. This also tries D2's
  one-round default.
- **Execution:** headless, on a plain export of this branch's HEAD loaded with `--plugin-dir`, in
  its own worktree, as D2's runs were. `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`, PC held awake.
- **Recorded per task:** each named-test check's wall time and exit status, fix rounds, and any
  halt or intervention. Plus the run's total cost.

## What decides named tests' default (fixed before the run; my call)

Named tests stay on by default only if all hold:
- the run finishes with no halt caused by the named-test check;
- no check is stopped at the 30-minute limit;
- the checks' total wall time is under half the run's execution time.

Otherwise the next change makes the named-test check opt-in per plan, off by default, and PR #6
is not merged with it on.

## Merge

The run's branch merges into `feat/backlog-model-fit` after a final review, so it lands in PR #6.
