# Design: D1 experiment, plans without a prescribed implementation

Date: 2026-11-12. Status: draft for Brett's review.
Backlog item: D1 in `docs/proposals/2026-11-12-charters-and-waves-backlog.md`.

## Why

An implementer sees only its task's text, and the reviewers treat that text as the binding spec.
A wrong instruction in a plan's `## Implementation` section is therefore built faithfully and
passes review, which leaves gate 2 as the only defence. Round 1 of gate 2 has never passed in
the consuming repo (21 of 21 plan audits NOT READY), plans there run 3,000 to 5,500 lines, and
Brett's estimate is about 2 million tokens for two gate-2 rounds on a large plan. Anthropic kept
its planner on product context and high-level design for the same reason; their case was a
greenfield app, and a repo with conventions may need the detail.

The question: does a plan with exact acceptance criteria, contracts and `files:`, but no
prescribed implementation, do as well for less?

## What success means (Brett's criteria)

Plan B (no implementation) against Plan A (normal), all four at once:

1. **Faster:** wall-clock time from the first plan draft to the last task done, gate 2 included.
2. **Cheaper:** tokens and estimated dollars over the whole pipeline.
3. **No loss of accuracy.**
4. **Hands off as well or better:** someone else, or a headless session (`claude -p`,
   overnight), can run the plan to the end without a person stepping in.

**Bar for the big run (Brett's):** Plan B at least 2x faster and 2x cheaper over the whole
pipeline, with no accuracy lost and no more interventions.

**Bar for the pilot (my call):** the pilot's plan is small, so gate 2 is a smaller share of its
cost and 2x overall is not expected even if the idea is right. A pass justifies the big run; it
does not change the default plan format.

## Decision rule (fixed before any run; my call except where marked)

The pilot passes only if every line holds:

| Criterion | Pass when |
|---|---|
| Acceptance | B fails no acceptance test that A passes. |
| Hidden suite | B fails no hidden-suite case that A passes. |
| Blind review | B's Important findings are no more than A's. |
| Hand-off | Both headless runs finish; B's interventions are no more than A's. |
| Gate 2 | B's gate-2 tokens, all rounds summed, are at most half of A's. Round 1 counts as the mean of its two draws. |

The big run uses the same accuracy and hand-off lines, and replaces the gate-2 line with Brett's
bar: B's whole-pipeline cost and active time each at most half of A's.

"A small difference" is anything inside those margins. The 2x margins are wide on purpose: one
sample per arm cannot resolve less.

## Definitions (my calls)

- **Finished:** the plan reaches a terminal state (every task `done`, `failed` or `skipped`) with
  no person typing into the run. Re-invoking a run that stopped is allowed, and it counts as one
  intervention.
- **Intervention:** any point where a person had to act: a re-invocation, a question the run
  asked, a permission prompt. Every NEEDS_CONTEXT is also counted, whether or not the controller
  answered it. The controller may answer one from the spec and the repo, as the executor does
  today. The count is taken afterwards from the transcripts by the measurement script, not by
  the controller.
- **Run budget:** each execution runs with a cap of twice Plan A's estimated cost, set before
  the run. Hitting the cap means it did not finish. The pinned plugin has no review-loop cap, so
  this is what bounds a loop.
- **Wall-clock:** reported two ways. *Elapsed* runs from the first draft to the last task done.
  *Active* is the sum of each turn's time, from the prompt to the last reply, so Brett's pauses
  between turns don't count. The bars use active time.
- **Shared draft:** Plan B is charged Plan A's round-1 drafting cost plus the conversion. Writing B
  directly would cost less, so B's plan-writing figure is an upper bound and the comparison
  leans against B.

## Two stages

1. **Pilot, in this repo.** Fully observable from a personal session; the winning branch merges.
2. **Big run, only if the pilot passes.** A long plan (thousands of lines) in a repo with real
   conventions; preferably personal work so it can be observed. If it runs in CrewTracks, it runs
   from a CrewTracks session and only numbers come back (workspace context rule).

This document designs the pilot and the tooling both stages share.

## Pilot work

One spec covering two backlog items, written and passed through gate 1 before either plan:

- **E5, generic part:** a `plan-state preflight` check run before dispatch: a path the task text
  says to edit that is in no task's `files:` (the smoke run's task-rename defect), a cited path
  that no longer resolves, a path a task modifies that does not exist and no upstream task
  creates.
- **Review-loop cap:** after N ISSUES rounds on one task, mark it `failed` instead of looping.

This repo has conventions a plan would normally spell out (awk that must run under gawk, mawk and
busybox; POSIX sh; the test harness; prompt wording), which tests the caveat.

## The two arms

- **Plan A:** written the normal way with `writing-dag-plans`.
- **Plan B:** Plan A's round-1 draft with each task's `## Implementation` replaced by a
  `## Contracts` section, and nothing else changed. Contracts hold signatures only: function
  names and arguments, command usage, exit codes, output and file formats. No function bodies,
  no test code. A fresh subagent does the conversion under that rule; the diff is checked by hand
  to confirm only those sections changed.

Each arm then goes through gate 2 until READY, with fixes made by a fresh session per arm so
neither sees the other's findings.

**What a Plan B fix may add (my call).** It may add or tighten acceptance criteria, contracts,
`files:`, dependencies, and prose that states *what* must hold. It may not add *how*: no function
bodies, no test code, no prescribed algorithm or idiom. If a finding can only be closed by
prescribing how, the fixer records it as "needs implementation". That is evidence about D1, so it
is reported, and the finding is closed by adding an acceptance criterion instead. At READY,
Plan B's diff against its converted draft is checked by hand, as at conversion, to confirm it is
still contracts-only.

**The repo's conventions (my call).** Today the awk and sh portability rule lives only in code and
history. Before the pilot the repo gets a short `CLAUDE.md` stating its conventions, portability
included. Implementers receive `CLAUDE.md` in both arms, so this is the realistic case the caveat
is about: conventions are written down, and the question is whether implementers follow them
without prescribed code. The hidden suite stays hidden in a narrower sense: neither plan names
the Docker command or its cases, so neither run can tune itself to them.

**Execution prompts (my call).** Unchanged. The executor, implementer and reviewer prompts are
the same for both arms. `## Contracts` is part of the task body, so the reviewers already treat it
as spec. The reviewer line about `## Implementation` blocks being a starting point simply has
nothing to apply to in Plan B. If reviewers flag the missing section, those ISSUES rounds are
counted and reported as their own line.

## What has to exist first

1. **A contracts-only plan mode** (experimental):
   - a plan-level frontmatter marker, e.g. `implementation: contracts-only`;
   - H7 accepts `## Contracts` in place of `## Implementation` when the marker is set;
   - H8, H9, H10, S13 and writing step 6.5 read code blocks in `## Contracts` the same way they
     read `## Implementation`, so contract sequencing is still checked rather than silently
     skipped;
   - gate-2 lenses are told the omission is deliberate and not a finding;
   - `plan-state check` accepts the marker;
   - plans without the marker behave exactly as today (a test proves it).
2. **A pinned plugin copy.** The pilot's work changes `plan-state` and the executor rules, so both
   runs load the plugin with `--plugin-dir` from one fixed checkout outside both worktrees.
3. **Measurement:**
   - a script, grown from the numbers-only usage counter used on 2026-11-12, that reports per run:
     tokens (with and without cache reads) and estimated dollars for the controller, each subagent
     type, and each gate-2 round; wall-clock per stage; never message content;
   - transcript retention raised (`cleanupPeriodDays`) so no run is deleted before it is counted.
4. **Accuracy checks neither plan can see:**
   - the full test suite run under gawk, mawk and busybox in Docker, kept outside the repo and
     never mentioned in either plan;
   - a blind final review of both branches labelled X and Y, by a reviewer told nothing about
     the experiment, which reports Important and Suggestion findings.

## Procedure

1. Build the prerequisites (their own small plan, normal format), including the repo `CLAUDE.md`.
2. Write the pilot spec; pass gate 1.
3. Write Plan A; derive Plan B; gate 2 on each until READY. Round 1 runs twice on each plan's
   draft (Brett's choice, 2026-11-12), because each gate-2 round is a fresh draw. Both draws are
   measured and averaged. The fixer works from the first draw's findings only; the second draw
   is for measurement. Later rounds run once.
4. Run each plan headless from its own worktree off the same base commit, one after the other
   on the same day, same models and tiers, Opus 5.5 controller.
5. Run the hidden checks and the blind review on both branches.
6. Merge the winning branch; delete the other. Report in
   `experiments/d1-no-implementation/REPORT.md`.

## Measures

| Measure | How |
|---|---|
| Wall-clock | first draft to last task done; per stage |
| Cost | tokens and $ per stage: plan writing, each gate-2 round, controller, implementers, reviewers, retries |
| Gate 2 | rounds to READY; blocking findings per round, by lens |
| Plan size | lines |
| Review | ISSUES rounds per task, BLOCKED, NEEDS_CONTEXT, failed tasks |
| Accuracy | acceptance tests; hidden portability suite; blind review findings; convention slips |
| Hand-off | interventions: any stop, question, or NEEDS_CONTEXT the controller could not answer from the plan |

## Evidence so far

A numbers-only count of the one CrewTracks DAG execution still on disk (2026-11-10): about $187
at list price, of which the controller session was about $104, implementers $61, quality
reviewers $18 (48 calls for 27 implementer dispatches), spec reviewers $3. Gate-2 transcripts
from before late October were deleted by transcript cleanup, so Brett's 2-million-token figure
is unverified.

The controller is over half an execution's cost, and Plan B may barely change it. That is why
the controller is measured separately. A 2x overall saving needs the controller's cost to fall
too.

## Non-goals

- Changing the default plan format. Contracts-only stays experimental until the big run.
- Reducing the controller's cost. Measured, not changed, in this experiment.
- Running anything in CrewTracks during the pilot.

## Anti-goals (a failure even if it runs)

- A hidden check leaking into either plan or either session.
- Plan B getting information Plan A did not, or the reverse.
- Declaring a result on a small difference from one sample.

## Left to the builder

- Exact names of the marker, the section, the script and the report layout.
- The shape of a `## Contracts` section beyond "signatures, usage, exit codes, formats; no
  bodies, no tests".
- The review-loop cap's N (in the pilot spec, not here).
