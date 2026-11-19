# D1 pilot report: plans without a prescribed implementation

Date: 2026-11-16.
Design: `docs/superpowers/specs/2026-11-12-d1-no-implementation-experiment-design.md`.
Feature built by every arm: `docs/superpowers/specs/2026-11-12-preflight-and-review-cap-design.md`
(`plan-state preflight`, `review_rounds` and the review-loop cap).

## Verdict

**The pilot fails. Arm A, the normal plan, wins and is the branch to merge. No big run.**

The B0 arm is an extra result that the decision rule doesn't cover. It suggests gate 2 is the
expensive step and bought no measurable quality on this feature. That is a new hypothesis,
not a finding, and it needs its own experiment (see "What to test next").

## Setup

| | A | B | B0 |
|---|---|---|---|
| Plan | normal (`## Implementation`) | contracts only | contracts only |
| Plan lines at execution | 1068 | 843 | 743 |
| Gate 2 | yes, 3 rounds | yes, 2 rounds | none |
| Branch, head | `d1/arm-a` 1757d4d | `d1/arm-b` 26b3474 | `d1/arm-b0` d988421 |

- All arms start from base `402d20b` and use the plugin pinned at `a771ddd`.
- All arms share one plan-writing session. B and B0 share one conversion session. B0's plan is
  the converted plan before any gate-2 fixes.
- Every stage ran headless (`claude -p`).
- B0 was not in the design's decision rule. It was added to separate the plan format from the
  cost of gate 2.

## Decision rule (B against A, fixed before the runs)

| Criterion | Pass when | Result | |
|---|---|---|---|
| Acceptance | B fails no acceptance test that A passes | both pass | PASS |
| Hidden suite | B fails no hidden case that A passes | A 12/12, B 9/12 | **FAIL** |
| Blind review | B's Important ≤ A's | B 2, A 1 | **FAIL** |
| Hand-off | both finish; B's interventions ≤ A's | B 0, A 1 | PASS |
| Gate 2 | B's gate-2 tokens ≤ 0.5 × A's | 0.60 | **FAIL** |

Three of the five lines fail, so the pilot fails. Even under the pilot's looser bar, B got
nowhere near Brett's 2x bar for the big run: B's pipeline cost 0.74 × A's and its active time
0.80 × A's.

## Measurements

From `measure.cjs`, run on 2026-11-16 over every session in the manifest.

| Arm | Gate-2 tokens | Pipeline tokens | Pipeline $ | Active time | Execution $ | Execution time | Interventions |
|---|---|---|---|---|---|---|---|
| A | 42.88M | 64.53M | $61.58 | 356 min | $13.25 | 182 min | 1 |
| B | 25.77M | 47.23M | $45.70 | 286 min | $11.65 | 141 min | 0 |
| B0 | 0 | 25.11M | $23.12 | 302 min | $17.26 | 248 min | 3 |

Round 1 of gate 2 counts as the mean of its two draws.

Where the money went:

- **A** spent $42.44 of its $61.58 on gate 2: round 1 averaged, then rounds 2 and 3.
- **B** spent $27.04 on gate 2: round 1 averaged, then round 2.
- **Execution** was the cheaper part in every arm, at $12–17.

## Accuracy

### Hidden check

The hidden suite ran in Docker under mawk, gawk and busybox, with `rg` installed.

| Arm | Result | Failure |
|---|---|---|
| A | 12/12 | — |
| B | 9/12 | `tests/plan-state/plan-state.test.sh` breaks under all three awks |
| B0 | 12/12 | — |

B's failure is at line 733 (`fails + : syntax error: operand expected`). When `rg -c` matches
nothing it prints an empty count, which breaks the suite's tally arithmetic. Every case
passes, but the suite exits non-zero. Gate 2 did not catch this bug.

The first hidden runs had no `rg` in the image. A then failed 3 suites and B failed 3 suites.
After `rg` was added, A passed all 12 and B still failed. The results above are from the image
with `rg`, which is now `hidden-check.sh`'s default.

### Blind review

Setup:

- One fresh Opus 5.5 reviewer per branch, each in a neutral detached worktree.
- The plan file was excluded from the diff.
- Branches were labelled X, Y and Z. The key is in `blind-key.txt`, which the reviewers never
  saw.

| Arm | Important | Suggestion | Convention slips |
|---|---|---|---|
| A | 1 | 9 | 1 |
| B | 2 | 8 | 2 |
| B0 | 2 | 8 | 0 |

Important findings:

- **A:** a quoted `review_rounds: "2"` passes rule 15 but is never rewritten, so the cap never
  fires.
- **B:**
  - the empty `rg -c` count breaks the suite's tallies (the same bug the hidden check found);
  - duplicate `review_rounds` lines defeat the cap.
- **B0:**
  - `./` in `files:` is not normalized, so a task's own file raises a P3 error;
  - the sentence-final strip test cannot fail.

Shared across arms:

- In all three branches, the reviewer re-dispatch prompts never mention the cap. All three
  reviews rated this a Suggestion.
- A has the same `./` bug as B0, but its reviewer rated it a Suggestion. B's reviewer did not
  report it.

## Caveats

1. **One sample per arm.** The design says the 2x margins are wide on purpose, because one
   run cannot resolve less. A one-finding gap in the blind review is within noise.
2. **A's time includes a restart.** A's first execution session stopped at the 10-minute
   background-wait ceiling and was re-invoked. That re-invocation is A's one intervention.
3. **B0's run was not clean.** It needed 3 re-invocations:
   - Session 1 stopped at the wait ceiling.
   - Session 2 ended on an auth 403 after about 3.5 hours and $8.33. Its partial work was
     stashed (`d1-b0-resume2-partial-task-preflight-verb`) and redone later. That inflates
     B0's execution cost and time.
   - Session 3 stopped at the wait ceiling.
   - Session 4 ran with `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`, unlike A and B, and
     finished.

   Two of the three interventions came from the wait ceiling and one from an auth failure;
   none was a NEEDS_CONTEXT or BLOCKED.
4. **Active time is model time, not wall-clock time.** Gaps between re-invocations, including
   overnight gaps, are excluded.
5. **The feature is small.** The design expected gate 2 to matter more on plans of thousands of
   lines.

## The B0 result

B0 against A:

| | Ratio |
|---|---|
| Pipeline cost | 0.38 |
| Pipeline tokens | 0.39 |
| Active time | 0.85 |

Accuracy was comparable:

- Both passed the hidden check 12/12.
- B0 had two Important findings to A's one. But one of B0's is a bug A also has, and A's one is
  arguably the most serious of all the findings.
- B0 had no convention slips.

What this does and does not show:

- **Almost all of the saving is gate 2.** B0's execution cost more than A's ($17.26 vs $13.25),
  partly because of the auth-403 rework. B0 is cheaper only because it skipped about $42 of
  audits.
- **Two variables changed at once.** B0 differs from A in plan format and in skipping gate 2.
  No arm ran A's normal plan without gate 2, so the B0 result cannot be credited to the
  contracts format.
- **Gate 2 didn't pay for itself here.** On this feature, the two arms with gate 2 (A, B) did no
  better than the arm without it. B, which went through gate 2, was the only arm to fail the
  hidden check.

## What to test next

1. Merge A, after fixing its Important finding (quoted `review_rounds`) and the two gaps shared
   across arms: the re-dispatch prompts should mention the cap, and `./` in `files:` should be
   normalized.
2. Run a gate-2 ablation: **A's normal plan with and without gate 2**, with the plan format held
   fixed. Ideally run it on a second, larger feature, and run both arms with the same
   wait-ceiling setting.
3. Contracts-only stays experimental, as the design requires. Nothing here supports changing the
   default plan format.

## Raw data

Everything sits next to this report. The scripts (`run-arm.sh`, `run-audit.sh`, `run-fix.sh`,
`convert-plan-b.sh`, `hidden-check.sh`, `measure.cjs`) and the prompts are the tools the
pilot ran with; `README.md` describes them. `manifest.json` keeps the absolute worktree paths
the runs used.

- `manifest.json`: every session by arm and stage, plus B0's notes.
- `runs/measure-20261116.txt`: the full per-stage tables.
- `runs/hidden-*-rg1.txt` and `runs/hidden-*-rg0.txt`: hidden-check output, with and
  without `rg`.
- `runs/blind-{X,Y,Z}.md`, `runs/blind-key.txt` and `runs/blind-scores.md`: the blind review.
- `runs/exec-done.txt`: execution start and end times, and exit codes.
