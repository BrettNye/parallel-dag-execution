# D2 report: does gate 2 pay for itself on a ~15-task plan?

Date: 2026-11-18.
Design: `docs/superpowers/specs/2026-11-16-d2-gate2-ablation-design.md`.
Feature built by every run: `docs/superpowers/specs/2026-11-17-named-tests-design.md` (E3: acceptance
criteria as named tests, `plan-state tests`, `verify-tests`).
Follows: `experiments/d1-no-implementation/REPORT.md`.

## Verdict

**The round1 arm wins: recommend one round of gate 2 instead of auditing to READY.**

The none arm fails the decision rule on one line, the trace. One gate-2 finding (F3: the
implementer is never given the task's `tests:` entries) shipped in both runs without gate 2.
Every other line held for none, at 0.4× full's cost.

round1 holds every accuracy, hand-off and trace line against full, and costs 0.61–0.69× full.
The trace line holds under one ruling, Brett's, on F5 (see "Trace"). Under the stricter reading
of "shipped", gate 2 would stay as it is.

As the design says, nothing changes in the plugin's defaults until the consuming-repo stage
confirms this on a large plan.

## Setup

| | none | round1 | full |
|---|---|---|---|
| Plan snapshot | S0 `d2-S0` dc30ba0 | S1 `d2-S1` 09fed21 | S2 `d2-S2` 4589c15 |
| Plan lines | 1423 | 1491 | 1536 |
| Gate 2 | none | round 1 + its fix | rounds 1-3 + fixes (READY) |
| Runs | none-1 (U), none-2 (T) | round1-1 (R), round1-2 (P) | full-1 (Q), full-2 (S) |

- All six runs start from base `c57de12` with the plugin pinned at `c57de12`.
- They share one plan-writing session. The plan has 16 tasks.
- Every stage ran headless (`claude -p`).
- The runs were interleaved (none, round1, full, then again) over 2026-11-17 and 2026-11-18.
- Letters are the blind-review labels (`runs/blind-key.txt`).

## Decision rule results

| Line | none vs full | round1 vs full |
|---|---|---|
| Hidden suite: no case fails in a challenger run that passes in both full runs | 303/303 in all six: PASS | PASS |
| Hidden check: no branch suite fails under any awk that passes in both full | 27/27 in all six: PASS | PASS |
| Blind review: Important ≤ full's + 1 | 4 ≤ 7: PASS | 3 ≤ 7: PASS |
| Hand-off: plan-caused interventions ≤ full's | 0 vs 0: PASS | 0 vs 0: PASS |
| Trace: no gate-2-fixed finding shipped in both runs | F3 shipped in U and T: **FAIL** | F5 didnt-matter in R and P: PASS (ruling) |
| Cost | 0.40× (≤ 0.6 needed): PASS | 0.61-0.69×, lower than full: PASS |

## Accuracy

| run | arm | hidden cases | hidden check (suites × awks) | Important | Suggestion |
|---|---|---|---|---|---|
| none-1 (U) | none | 303/303 | 27/27 | 2 | 14 |
| none-2 (T) | none | 303/303 | 27/27 | 2 | 12 |
| round1-1 (R) | round1 | 303/303 | 27/27 | 1 | 17 |
| round1-2 (P) | round1 | 303/303 | 27/27 | 2 | 8 |
| full-1 (Q) | full | 303/303 | 27/27 | 4 | 16 |
| full-2 (S) | full | 303/303 | 27/27 | 2 | 12 |

Summed Important: none 4, round1 3, full 6.

- **The hidden suite hit its ceiling.** All six branches pass every case, so it does not separate
  the arms. Step 13 had nothing to drop.
- **full-1's two extra Important findings are not gate-2-shaped:**
  - its own signal tests failed a 25 s threshold when the reviewer re-ran them under load (the
    hidden check passed them);
  - it has two gaps in the executor text.
- **The commonest Important finding is in four of six branches, across every arm.** SKILL.md
  assumes the Bash tool's 600000 ms timeout kills `verify-tests`. In fact the tool moves the call
  to the background without a signal, so the gap is in the spec itself.
- **Convention slips:** Q committed `verify-tests` as mode 100644.

## Trace

Gate 2 fixed five blocking findings: four in round 1 and one in round 2. Round 3 was READY.

| | F1 bad EU1 case | F2 KILL/prune | F3 `tests:` not given to implementer | F4 before tree keeps test files | F5 new test files not deleted |
|---|---|---|---|---|---|
| U (none) | didnt-matter | didnt-matter | **shipped** | didnt-matter | didnt-matter |
| T (none) | didnt-matter | didnt-matter | **shipped** | didnt-matter | didnt-matter |
| R (round1) | fixed in plan | fixed | fixed | fixed | didnt-matter |
| P (round1) | fixed in plan | fixed | fixed | fixed | didnt-matter |

The full table, with evidence, is in `runs/trace/trace-result.md`. The tracer was one fresh
Opus subagent working from the letters only. Brett spot-checked F3·U, F5·R and F1·T, and all
three held.

- **F1 and F2 were caught by the implementers.** Both none implementers kept the correct
  `not-red` label and reported the bad example as a concern. Both deleted the leaked temporary
  directory in the KILL case, rather than having `verify-tests` remove worktrees it did not
  create.
- **F3 is the one that shipped.** It is a defect in text: a later plan's implementer can't see
  the exact case names it must satisfy. Nothing downstream caught it:
  - **Per-task review:** the merged reviewer returned `SPEC: APPROVED / QUALITY: APPROVED` in
    both U and T, because the section "matches the task's implementation block verbatim". A
    per-task reviewer judges a task against its own text, and here the defect was the text.
    Seeing it means reading the executor's prompt template, which renders the id, files,
    depends_on and body, never the YAML block. That is outside the task.
  - **Blind review:** U's reviewer flagged a neighbouring Important issue, the merged reviewer's
    red-to-green rule (part 3 of the gate-2 fix), but not the missing `tests:` rendering. T's
    reviewer flagged neither.
  - **Tests:** no test exercises it.
  - That fits D1's observation: gate 2 earns its keep on cross-file wiring that no test exercises.
- **F4 and F5: the code is right in every run, but the regression cases are missing.** Ruling
  (Brett): didnt-matter, because the spec's "shipped" means the bug is in the final branch.
  - F5's case is in both full branches and neither round1 branch.
  - F4's case is in round1 and full, not in none.
  - These missing cases are the visible cost of skipping later rounds. They are not a defect
    in what was built.

## Cost

`measure.cjs`: pipeline $ = shared gate-2 charge + mean execution.

| stage | $ | active |
|---|---|---|
| plan writing (all arms) | 3.47 | 9m |
| gate 2 round 1 + fix | 16.70 + 1.02 | 29m |
| gate 2 round 2 + fix | 9.46 + 0.84 | 18m |
| gate 2 round 3 (READY) | 5.72 | 8m |

| arm | pipeline $ (infra stops excluded) | pipeline $ (infra sessions counted) | × full |
|---|---|---|---|
| none | 24.66 | 24.66 | 0.40 / 0.39 |
| round1 | 37.24 | 43.86 | 0.61 / 0.69 |
| full | 61.40 | 63.92 | 1 |

| run | execution $ (all sessions) | active | ISSUES verdicts |
|---|---|---|---|
| none-1 | 22.26 | 180m | 3 |
| none-2 | 20.12 | 185m | 1 |
| round1-1 | 21.56 | 136m | 2 |
| round1-2 | 23.79 | 303m | 1 |
| full-1 | 29.21 | 217m | 4 |
| full-2 | 24.21 | 235m | 0 |

- **Two runs hit infra stops.** full-1 stopped after 8 tasks and round1-2 after 14, both on
  ENOTFOUND when the network changed as Brett moved between home and work. Both were re-invoked
  and finished all 16 tasks.
- **measure.cjs undercounts a run with an infra stop.** It leaves the infra session out of the
  run's cost: round1-2 shows $10.55 that way. Both ways are given above
  (`runs/measure-excl-infra.txt`, `runs/measure-incl-infra.txt`).
  - In the second file, the re-invocation shows as 1 "intervention". It is infra, not
    plan-caused.
- **Execution cost is about the same in every arm.** All of the difference is gate 2 itself:
  rounds 2 and 3 cost $16 together.
- **Gate 2 by lens (`audit-stats runs/audit-gate2-r3`).** The three rounds raised 5 blocking
  findings. No lens raised a blocker alone:
  - coherence 4, verifiability 4;
  - ambiguity 3;
  - context-sufficiency 2, grounding 2;
  - coverage 1;
  - charter and dag-integrity 0.
- **Run audit-stats on the last snapshot only.** Each round's snapshot directory holds the
  earlier rounds too. Running it over `runs/audit-gate2-r*` counts them repeatedly (14
  "blocking").

## Execution

- **Every run finished all 16 tasks.** No preflight halts, no BLOCKED, no review-cap failures
  and no plan-caused interventions.
- **Every run left its plan's status edits uncommitted.** That's how the executor behaves;
  it's not arm-specific.
- **Every run independently flagged three things:**
  - the verify-tests-on-this-repo timing: 606-1710 s against the plan's "about 85 s" (EMP-1);
  - the Bash tool timeout sending no signal;
  - the none runs only: the spec's `round on "2" counts to 3` example coming out `not-red`.

## Caveats

- **One plan in one repo, two runs per arm.** S0 was already a good plan: gate 1 ran on its spec,
  and its author applied D1's lessons. A weaker plan may need more of gate 2.
- **The hidden suite is at ceiling,** so accuracy rests on the blind review and the trace.
- **The round1 verdict depends on the F5 ruling.** If a missing regression case counts as
  shipped, gate 2 stays as it is.
- **Contamination, none known to affect results:**
  - executors left prompt and work directories in the shared runs folder. They were moved out
    between runs; copies are in scratch, not committed.
  - `git worktree list` in each run showed its sibling worktrees.
  - two blind reviewers had their test logs garbled by a shared scratchpad, re-ran into their
    own directories, and their findings stand.
- **Full-1 was hurt by load.** Its suite's timing failures appeared only when another suite was
  running on the machine.

## What to do with it

Agreed with Brett on 2026-11-18.

**Keep as is:**
- **Gate 1.**
- **Gate 2 round 1, required.** Without it, F3 shipped and nothing downstream caught it.
- **All 8 lenses.** Five blockers are too few to drop a lens on.
- **Per-task review's scope.** Widening it would charge every task for what gate 2 catches once
  per plan.

**Change now (defaults unchanged):**
1. **A plan-quality rule for F3's shape.** A task that adds a prompt or template section that
   reads a field must also deliver that field to the section's reader, or name the task that
   does. It runs free when the plan is written.
2. **Gate 2's resolution for each blocking finding names the criterion or test that pins the
   fix.** Missing pinning cases (F4/F5) were all that rounds 2-3 left behind in the round1 runs.

**Change later, after the consuming-repo stage confirms it on a large plan:**
3. **Make one gate-2 round plus its fix the default,** with running to READY opt-in. That saves
   about $16 per ~15-task plan, roughly 30% of the pipeline.

**Comes with merging E3 (step 15):** fix the executor SKILL.md's Bash-timeout assumption. It is
Important in 4 of 6 branches, across every arm, so it's a spec defect gate 2 could not see.
Also correct the "about 85 s" figure.

## Files

- `README.md`: the procedure that was followed.
- `manifest.json`: every session id by stage and run, plus notes.
- Tools: `measure.cjs`, `make-run.sh`, `run-arm.sh`, `hidden-check.sh`, `make-blind.sh`.
- `runs/`:
  - `hidden-*.txt`, `blind-*.md`, `blind-key.txt`, `run-map.txt`;
  - `measure-*.txt`;
  - `audit-gate2-r*/`, the gate-2 lens reports and reconciliations;
  - `trace/findings.md` and `trace/trace-result.md`;
  - `trace/<L>/diff.patch`, `hidden-check.txt` and `blind-review.md`.
- `hidden/`: the hidden functional suite (was `scratch/d2-hidden`).
- Not committed: the trace transcripts (80 MB, in `scratch/d2-trace-transcripts/`).
- `final-plans/`: the plan each arm executed: S0 (dc30ba0), S1 (09fed21) and S2 (4589c15).
  The tags and the `d2/gate2` branch were deleted after the merge, so these copies are the record.
