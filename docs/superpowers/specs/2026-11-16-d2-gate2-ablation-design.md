# Design: D2 experiment, what gate 2 buys

Date: 2026-11-16. Status: approved by Brett, 2026-11-16.
Backlog item: D2 in `docs/proposals/2026-11-12-charters-and-waves-backlog.md`.
Follows: the D1 pilot, `experiments/d1-no-implementation/REPORT.md`.

## Why

In the D1 pilot, gate 2 cost $42 of arm A's $61.58 pipeline, about 70%. The arm that skipped it
(B0) cost 0.38x as much and was as accurate: both passed the hidden check 12/12, and the blind
review found 2 Important issues in B0 and 1 in A. B0 changed the plan format as well, though, so
the pilot could not credit the saving to skipping gate 2. And one run per arm cannot separate a
one-finding difference from noise.

This experiment tests gate 2 on its own. The plan format stays the same in every arm, and
`plan-state preflight` (merged after D1) runs in every arm. The question: on a plan of about 15
tasks, does gate 2 (in full, or only its first round) change the outcome enough to pay for itself?

The answer decides whether gate 2 stays required, is cut to one round, or becomes optional.

## Goals

- Measure what gate 2 adds to accuracy and hand-off, against what it costs, with the plan format
  held fixed.
- Separate round 1 from the later rounds. In D1, A's rounds 2 and 3 cost $28.
- For each blocking finding gate 2 fixed, find out what happened when the plan ran without the
  fix.

## Non-goals

- Changing which lenses run. A fewer-lenses arm waits until `audit-stats` has more reports
  (approach C, below).
- Changing the plan format. Every arm uses the normal format.
- Running in the consuming repo. That is the next stage, and only if this result holds.

## Anti-goals (a failure even if it runs)

- Arms that differ in anything but the plan text gate 2 changed: base commit, plugin, models,
  settings, or run conditions.
- Declaring a result on a one-finding difference.
- The hidden check or the blind review leaking into any plan or session.
- An infrastructure failure (an auth error, a wait-ceiling stop) counted as the plan's fault.

## Approaches

Brett picked B on 2026-11-16, after picking a bigger feature in this repo (option 1) over a large
plan in the consuming repo or a rerun of the pilot feature.

- **A. Independent arms, as in D1.** Each arm gets its own copy of the plan and its own gate 2.
  This pays for gate 2 more than once, and different audit draws make the arms' plans drift
  apart. About $350–450.
- **B. One gate-2 run, three snapshots. Picked.** Gate 2 runs once, in full, and the plan is
  saved at three points. The arms differ only in what gate 2 changed. Gate 2 is paid once, and
  its cost per round is read from that one run. The cost of this choice: gate 2's own variance is
  not sampled. D1's two round-1 draws on arm A cost within 6% of each other ($13.42 and $15.09),
  which makes one run acceptable. About $150–200.
- **C. B plus a fewer-lenses arm.** Not now: four reconciler reports are too few to choose the
  lens set.

## Work

**Feature: E3 from the backlog, acceptance criteria as named tests (my call).**
- A task lists the tests that prove it.
- A script checks that each named test exists, failed first, and passes now. `plan-state` is the
  natural home for it.
- It touches `plan-state`, the plan format, the executor and the reviewer prompts, so its plan
  should have about 15 tasks with real dependencies.
- E3 gets its own spec, brainstormed separately, and passes gate 1 before any plan is written.
  This design does not settle E3's content.

If E3's plan comes out much smaller than 12 tasks, say so before running. A small plan repeats the
pilot's weakness.

## The three arms

1. Write the plan once with `writing-dag-plans` (normal format) from the E3 spec, which has
   passed gate 1. Commit it as **snapshot S0**.
2. Run gate 2 round 1 (one draw), and fix its findings in a fresh session. Commit the result as
   **snapshot S1**.
3. Continue gate 2 until READY, or until the convergence rule stops it (the blocking count holds
   while the plan grows). Commit the final plan as **snapshot S2**.

**Later rounds follow the skill as written (decided from the project).** Rounds 2 and later run
the diff-scoped re-audit that `auditing-artifacts` describes: only the lenses the diff touches,
with the others carried, and the skill's stop rule. D1's script forced all eight lenses every
round, which is not today's pipeline. Lens scoping makes later rounds cheaper, so the round1 cost
line in the decision rule asks only that round1 cost less than full (see below).

| Arm | Plan | Charged with |
|---|---|---|
| none | S0 | plan writing |
| round1 | S1 | plan writing + round 1 + its fix |
| full | S2 | plan writing + every round + every fix |

Edge cases:
- If round 1 returns READY, S1 and S2 are the same plan. Run the full arm only and report it.
- If gate 2 ends at the convergence stop and not at READY, S2 is the plan as it stopped. That is
  what the pipeline would hand to execution, so it is what gets tested.

## Execution

- **Two runs per arm, six in all.** Each run starts from its own worktree at the same base
  commit, with its arm's snapshot as the plan file.
- **One pinned plugin copy** at the base commit, loaded with `--plugin-dir` in every run.
  - It includes `preflight` and the review-round cap.
  - The plan file is not in the pinned copy.
- **Same settings everywhere (my call):**
  - Opus 5.5 controller, default tiers;
  - `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` in every run, so the D1 ceiling stops can't recur;
  - the PC held awake for the whole run.
- **Interleaved order:** none, round1, full, then none, round1, full. Load and time-of-day
  effects then spread across the arms.
- **Run budget:** each run is capped at twice the full arm's planned execution cost, set before
  the first run. Hitting the cap means the run did not finish.
- **A preflight halt is fixed and resumed, and charged to the arm (my call).** A plan that
  hasn't been through gate 2 is the one most likely to stop at `preflight` before any task
  runs. That is the pipeline working as designed, so the run is not dead.
  - A fresh session fixes only what preflight printed. It sees the plan, the preflight output
    and the repo; it doesn't see the spec's audit or any other arm.
  - The fix's cost goes to that arm.
  - The halt counts as one plan-caused intervention.
  - Each fixed error is a "caught by preflight" outcome in the finding trace.
  - The same applies to a resumed run that preflight halts again.
- **A run that hits the budget cap fails the hand-off line for its arm.** Its partial branch still
  gets the hidden check and the blind review, which are reported for information.
- **An infrastructure stop is resumed and logged as infra.** That covers an auth error, a crash,
  or the machine sleeping. Infra stops are reported but don't count as interventions. If a run
  has more than two infra stops, it is rerun from the start.

## Accuracy, hidden from every run

**A hidden functional suite for E3 (Brett's choice, 2026-11-16).** Gate 2 mostly adds and
tightens acceptance criteria and tests. So a branch built from an unaudited plan is likely to
carry fewer and weaker tests of its own, and it would have less to fail. Every arm is therefore
graded against one fixed suite, the same for all six branches:
- A separate session writes it from the E3 spec, after gate 1 and before any plan is written. It
  sees the spec only, not any plan.
- It tests E3's behaviour through the interface the spec pins down: commands, arguments, exit
  codes, output. So the E3 spec must pin that interface exactly; gate 1 checks this as for any
  spec.
- It stays outside the repository until the last run has finished. Anything committed before
  the base commit would be in every run's worktree. It is then committed into
  `experiments/d2-gate2-ablation/` with the report. No plan or session is told it exists.
- It runs in the Docker check, after each branch's own suites, under the same three awks.
- If a case fails on every branch, including both full runs, the case is examined before
  scoring. If the suite is wrong, the case is dropped and the report says so.

The same tools as D1, copied into `experiments/d2-gate2-ablation/`:

- **The hidden check.** Every suite of the branch, then the hidden functional suite, runs in
  Docker under mawk, gawk and busybox awk, with `rg` installed.
- **A blind review of each of the six branches.**
  - Each review uses a fresh Opus 5.5 reviewer, in a neutral detached worktree, with the plan file
    excluded from the diff.
  - Each branch gets a random letter label, and the key stays in `blind-key.txt`.
  - The prompt is D1's `blind-review-prompt.md`, unchanged.

**The finding trace.** This is new, and it is the most direct evidence. For each blocking finding
gate 2 fixed (between S0 and S2), sort what happened in each run that lacked the fix into one of:

- **caught by preflight**: a preflight error or warning names it;
- **caught by per-task review**: an ISSUES verdict on the affected task fixed it;
- **broke the run**: BLOCKED, failed, or NEEDS_CONTEXT on the affected task;
- **shipped**: the bug is in the final branch, found by the hidden check or the blind review;
- **didn't matter**: none of the above. The implementer did the right thing anyway, or the
  finding had no effect.

A fresh subagent does the sorting from the transcripts and branches. It is given the findings
and the run labels, not the arm names. Brett spot-checks it.

## Measures

| Measure | How |
|---|---|
| Cost | tokens and $ per stage: plan writing, each gate-2 round, each fix, each execution (`measure.cjs`) |
| Time | active time per stage |
| Gate 2 | rounds; blocking findings per round, by lens (`audit-stats`) |
| Execution | ISSUES rounds per task, review-cap failures, BLOCKED, NEEDS_CONTEXT, failed and skipped tasks |
| Accuracy | hidden functional suite (cases passed); each branch's own suites under three awks; blind-review Important and Suggestion counts; convention slips |
| Hand-off | interventions caused by the plan (questions, NEEDS_CONTEXT, stops); infra stops listed apart |
| Trace | each gate-2 finding's outcome in each run without its fix |

## Decision rule (fixed before any run; my call)

Comparisons use both runs of each arm. "Worse" means worse in both runs, or worse by more than one
finding in their sum. One run being off by one is noise.

**Recommend making gate 2 optional (the none arm wins)** only if all of these hold, comparing
none against full:
- Hidden functional suite: no case fails in either none run that passes in both full runs.
- Hidden check: no branch suite fails under any awk in either none run while passing in both
  full runs.
- Blind review: the none runs' total Important findings are at most the full runs' total + 1.
- Hand-off: the none runs' plan-caused interventions are at most the full runs'.
- Trace: no finding gate 2 fixed is "shipped" in both none runs.
- Cost: the none arm's pipeline cost is at most 0.6x the full arm's.

**Otherwise, recommend one round (the round1 arm wins)** if the same accuracy, hand-off and trace
lines hold for round1 against full, and round1's pipeline cost is lower than full's. Diff-scoped
later rounds are cheap, so a fixed ratio here would rule round1 out before the runs.

**Otherwise, gate 2 stays as it is.**

Every result is reported for a ~15-task plan in this repo. Nothing changes in the plugin's
defaults until the consuming-repo stage confirms it on a large plan.

## Afterwards

- **Which branch merges:** among the full arm's two runs, the more accurate one (hidden check
  first, then fewer Important findings, then lower cost), after its Important findings are fixed.
  The full arm is chosen so the merged code went through today's pipeline whatever the result.
- **Report:** `experiments/d2-gate2-ablation/REPORT.md`, with the raw data beside it, the same
  layout as D1.
- **Clean-up:** delete the other branches and worktrees after the report is committed.

## Left to the builder

- Script and file names under `experiments/d2-gate2-ablation/`.
- How the manifest records snapshots and infra stops.
- The finding-trace subagent's prompt, within the rules above.
- The functional-suite writer's prompt, and the suite's layout, within the rules above.
- The exact run budget figure, within the rule above.
