# Design: C5 pilot, cheaper model settings for gate 2's first round

Date: 2026-11-19. Status: parked 2026-11-24, not run. Why: see C5 in the backlog.
Backlog items: C5, with D3 folded in, in `docs/proposals/2026-11-12-charters-and-waves-backlog.md`.
Follows: the D2 experiment, `experiments/d2-gate2-ablation/REPORT.md`.

## Why

D2 found that one gate-2 round is worth keeping and later rounds mostly are not. Round 1 is
now the main fixed cost of planning: $16.70 of the round1 arm's $37.24 pipeline in D2. Its
lenses and reconciler run on the most expensive settings the plugin has. Four lenses run on
`opus` (coverage, context-sufficiency, verifiability, ambiguity) and four on the `standard`
tier, which is Sonnet (dag-integrity, grounding, charter, coherence). The reconciler runs on
`opus`. Both agents pin `effort: high` in their frontmatter.

Opus 5.5 at `medium` effort is reported to beat Opus 5 at `high`, and Sonnet 5.5 costs about
half of Opus. If a cheaper setting finds what round 1 finds today, it should be the default.
C5 says to change a default only where measurement holds. This is that measurement, for gate 2's
round 1 only.

D3 asks whether a reviewer from a different model than the author reviews better. The plan
here was written by Opus, so the Sonnet-lens settings below answer D3 for gate 2 at no extra
cost.

## Goals

- For each candidate setting, measure what round 1 finds on a plan whose defects are known, and
  what it costs.
- Recommend one setting as the new default for gate 2's lenses and reconciler, or keep today's.

## Non-goals

- Gate 1, the per-task reviewers and the implementers. Their tiers stay as they are.
- Later gate-2 rounds. D2 already points at one round.
- Changing which lenses run, or how many.
- Settings that cost more (`max` effort, a `fable` tier). The goal is cheaper at the same
  quality (Brett, 2026-11-19).
- Running a plan through execution. D2 showed that what round 1 finds is what protects the
  built code, so finding is the measure.

## Anti-goals (a failure even if it runs)

- Settings that differ in anything but model and effort: plan, plugin version, controller,
  prompt or run conditions.
- A setting credited with a finding the reconciler did not keep as BLOCKING. Only BLOCKING
  findings get fixed, so a finding downgraded to DEFERRED is a miss.
- A setting that did not take effect (a lens that ran on the wrong model) counted as a result.
- Declaring a result on one draw.

## Approaches

Brett picked A on 2026-11-19.

- **A. Re-run round 1 only, scored against D2's known findings. Picked.** Each setting audits
  D2's frozen plan twice. No fix, no execution. About $80–130.
- **B. Full pipeline per setting, as in D2.** Audit, fix, execute, hidden suite and blind review
  for each setting. About $400 or more, and D2's hidden suite hit its ceiling (303/303 on every
  run), so it would not separate the settings.
- **C. Downgrade one lens at a time.** Finer-grained, but 16 or more runs, and it never tests
  the reconciler, which is where a cheap setting could drop a finding.

## The test bed

- **Plan:** D2's snapshot S0, the plan before gate 2, kept as
  `experiments/d2-gate2-ablation/final-plans/S0-none-dc30ba0.md`. It has no audit record.
- **Base:** each run gets its own fresh worktree at `c57de12`, D2's base, with S0 copied to the
  plan's path, `docs/superpowers/plans/2026-11-17-named-tests.md`. The E3 spec at that commit is
  the plan's parent spec.
- **Plugin:** pinned at `c57de12`, D2's pin, with `pin-plugin.sh`. Today's plugin has S18, which
  targets F3 directly and would credit every setting with it.
- **Runner:** D2's `run-audit.sh` with round 1, unchanged: headless, `--model opus` controller,
  all eight lenses in one message, then the reconciler, no fixing.

**Ground truth: D2's five blocking findings** (`experiments/d2-gate2-ablation/runs/trace/findings.md`).
- F1–F4 were found by D2's round 1; F5 by round 2.
- F3 is the one that mattered: it shipped in both D2 runs without gate 2, and per-task review
  approved it.

## The settings

Four settings, each a separate pinned copy of the plugin. Only these lines change:
- **Lens models:** the tier table in `skills/auditing-artifacts/lenses-plan.md`. Each lens call
  passes `model: resolve_model(lens.tier)` (`auditor-prompt.md:112` at the pin), which
  overrides the agent's frontmatter, so the table is what sets them.
- **Reconciler model:** the `model:` value in the reconciler's Agent call,
  `skills/auditing-artifacts/reconciler-prompt.md:121` at the pin, which hard-codes
  `resolve_model("opus")` and overrides the frontmatter. D2's round-1 transcript shows the
  controller passed it. (My call, after the builder check: this line is a model setting, so
  changing it keeps runs differing only in model and effort.)
- **Effort:** the `effort:` frontmatter of `agents/dag-auditor.md` and
  `agents/dag-audit-reconciler.md`. Neither prompt passes `effort` on the call, so the
  frontmatter takes effect.

| Setting | Lenses | Reconciler | Effort (both) |
|---|---|---|---|
| **today** | catalog: 4 `opus`, 4 `standard` | `opus` | high |
| **medium** | catalog: 4 `opus`, 4 `standard` | `opus` | medium |
| **sonnet-lenses** | all 8 `standard` | `opus` | high |
| **all-sonnet** | all 8 `standard` | `sonnet` | high |

- **today** is rerun, not taken from D2. D2's round 1 is a single draw. It is reported beside
  the new draws for information only.
- **sonnet-lenses** is D3's question: Sonnet lenses reviewing a plan Opus wrote.
- The controller stays on Opus in every run. It dispatches and collects; it does not judge
  findings.

## Execution

- **Two draws per setting, eight runs.** Order is interleaved: today, medium, sonnet-lenses,
  all-sonnet, then the same again, so load and time of day spread across settings.
- `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` and the PC held awake for every run, as in D2.
- **Check that each setting took effect.** After each run, read the model and effort of every
  lens and reconciler dispatch from the session's subagent transcripts. A run where any
  dispatch ran on the wrong model or effort is discarded and rerun, and the report says so.
- **An infrastructure stop** (auth error, crash, machine asleep) is rerun from the start and
  logged as infra. It is not charged to the setting.
- Each run's `.audit/` directory is kept under the experiment's `runs/`, as `run-audit.sh`
  already does.

## Scoring

**A blind judge.** One fresh Opus session, given:
- F1–F5 as written in D2's `findings.md`;
- each run's `reconciliation.md` and lens reports, labelled by a random letter, with the
  setting names hidden (key in `blind-key.txt`);
- the S0 plan, the E3 spec and the repo at `c57de12`.

For each run it reports:
- **F1–F5:** for each, whether a BLOCKING finding in the reconciliation states the same defect.
  A finding that names the same defect with a different fix counts. One that only touches the
  same task does not.
- **Every other BLOCKING finding:** real (building the plan as written would produce a defect
  or an unmeetable criterion), false alarm, or a duplicate of another finding in the same run.

Brett spot-checks three rows of the judge's table, as in D2.

## Measures

| Measure | How |
|---|---|
| Cost | $ and tokens per run, from `measure.cjs` over the session and its subagents |
| Time | wall time per run |
| Finds | which of F1–F5 each run kept as BLOCKING |
| Other blocking | count of real and false-alarm blocking findings per run |
| Settings check | model and effort of each dispatch, per run |

## Decision rule (fixed before any run; my call)

Each comparison sums both draws of a setting against both draws of **today**.

A cheaper setting **wins** only if all of these hold:
- **F3:** found as BLOCKING in both of its draws.
- **F1–F4:** total found is at least today's total minus 1.
- **False alarms:** total false-alarm BLOCKING findings is at most today's total plus 2. Each
  one costs a fix pass.
- **Cost:** mean cost per run is at most 0.7× today's mean.

If more than one setting wins, recommend the cheapest. If none wins, the defaults stay, and the
report says which line each setting failed. F5 and real findings outside F1–F5 are reported,
not scored: they show whether a setting finds more, which is not the goal.

**If today itself misses F3 in a draw,** the bar for F3 cannot be applied as written. Report it
and score F3 as "found at least as often as today."

## What the result changes

- A winning setting becomes the new default in `lenses-plan.md` and the two agents'
  frontmatter, and it is the setting the consuming-repo trial of one-round gate 2 uses.
- The report records D3's answer for gate 2: whether Sonnet lenses did better, the same, or
  worse on an Opus-written plan.
- Nothing changes for gate 1. A gate-1 run would need its own known-defect spec.

## Files

Tools and data go in `experiments/c5-gate2-settings/`, beside D1 and D2:
- `README.md` with the run order and commands;
- the setting patches, or a script that makes the four pinned copies from one pin;
- `run-audit.sh` and `measure.cjs` copied from D2, so the experiment stands on its own;
- the judge prompt;
- `runs/` and `REPORT.md`.

## Left to the builder

- How each pinned copy is patched (a script with `sed`, or kept patch files), as long as the
  diff from the pin is only the lines named in "The settings".
- How the settings check reads model and effort from the transcripts. Read the assistant
  messages' model or the subagent's `meta.model`, not a text search: in D2 every Sonnet lens
  transcript also holds one `claude-opus-5-5` string (an `api-request-shape` record, and
  `pickedEffortModel` in its `.meta.json`), which a search would flag as wrong.
- Scrubbing the judge's inputs. Some lens reports name tiers ("Opus tier may find it
  unaided"), which would hint at the setting behind a run.
- Where the worktrees live, as long as it is outside this repo and outside `scratch/`'s
  dependents rule.
