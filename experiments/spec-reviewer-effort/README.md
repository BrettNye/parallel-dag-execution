# Experiment: spec reviewer at `effort: low` vs `medium`

**Question.** Can `dag-spec-reviewer` drop from `effort: medium` to `effort: low`
without missing spec violations?

**Why a replay, not a live run.** The spec reviewer is the only stage that checks
a task against its spec. A miss at `low` would look like a clean pass in a real
run, so a live run can't show it. Instead, both variants review the same past
tasks, including tasks with planted defects.

This directory is experiment scaffolding. It is not part of the plugin and is not
meant to merge to `master`.

## What's here

| Path | What it is |
|---|---|
| `../../.claude/agents/exp-spec-reviewer-{medium,low}.md` | Same body as `agents/dag-spec-reviewer.md`. The two differ only in `effort:`. Project-level agents, so they register when a session starts on this branch. |
| `cases/C01–C14.md` | Real completed tasks from four past plans: frozen task text, the implementer's commit, and its files. Presumed clean. |
| `cases/R01–R03.md` | Real tasks whose commit a later commit patched. Ground truth unknown, so they're reported but don't count toward the decision. |
| `seeds/S01–S06.patch`, `seeds/map.txt` | One planted defect each, applied on top of a clean case's commit: 3 under-build, 2 over-build, 1 wrong value. |
| `build-seeds.sh` | Builds the seeded commits locally (same parent and message as the original, so they look like ordinary implementer commits). Never pushed. |
| `answer-key.md` | What each seed is and how to score. Never shown to a reviewer. |

## Protocol (for the runner session)

1. **Preflight.** Confirm `exp-spec-reviewer-medium` and `exp-spec-reviewer-low`
   are in the agent registry. If either is missing, stop and report; don't
   substitute another agent.
2. **Build the seeds.** `mkdir -p experiments/spec-reviewer-effort/results && experiments/spec-reviewer-effort/build-seeds.sh > experiments/spec-reviewer-effort/results/seed-shas.txt`
3. **Build each prompt mechanically** from the fenced template under
   `## Prompt template` in `skills/executing-dag-plans/spec-reviewer-prompt.md`:
   - `{task.id}` → the case's `task:` value
   - files → the case's `files:` list
   - `{task.body}` → the case file's content after its frontmatter
   - `{commit_sha}` → the case's `commit:` (for a seed, its SHA from `seed-shas.txt`)
   - Leave "project conventions" and "re-dispatch addenda" out.

   The prompt must not mention the experiment, effort, seeds, or expected
   outcomes. Both variants get the identical prompt for a case. Save each one to
   `results/prompts/<case>.md`.
4. **Dispatch.** Use the Agent tool with `subagent_type: exp-spec-reviewer-<variant>`
   and `model: "sonnet"`, running in the background, at most 10 per message, with
   both variants mixed in each batch.
   - C01–C14 and R01–R03: 1 run per variant (34 runs)
   - S01–S06: 2 runs per variant (24 runs)
   - 58 runs in total. Run ids look like `C03-low-1` or `S01-medium-2`.
5. **Record each run** as it finishes:
   - The reviewer's full report, verbatim → `results/raw/<run-id>.md`
   - One row in `results/runs.csv` with `run_id,case,variant,rep,verdict,subagent_tokens,tool_uses,duration_ms`.
     Take the numbers from the task notification's usage block.

   A run that errors or returns empty is re-dispatched once. If it fails again,
   record it as `ERROR` (not a pass).
6. **Score.** Only after every run is recorded, read `answer-key.md`:
   - **Seeds:** a run catches a seed only if it returns ISSUES and one issue names
     the planted defect.
   - **C cases:** decide whether each ISSUES is real or false, and write down why.
   - **R cases:** report only.
7. **Decide** with this rule. Recommend `low` only if both hold:
   - (a) every seed run caught at `medium` was also caught at `low`, and
   - (b) `low` has no more false positives on C01–C14 than `medium`.

   Otherwise recommend staying at `medium`.
8. **Write `results/REPORT.md`.** Open with the recommendation and the token
   saving: median and total `subagent_tokens` per variant, as a percentage
   difference. Then include:
   - a per-seed catch table
   - clean-case verdicts with the adjudication of each ISSUES
   - the R-case verdicts
   - every disagreement between the variants, quoting both
   - the limits of the test
9. **Commit** `results/` (not the seeded commits) and push to this branch. Don't
   change `agents/`, `skills/`, `cases/`, `seeds/` or `answer-key.md`. Don't open
   a PR.

## Known limits

- The tasks are markdown skill edits from this repo. Spec review on code-heavy
  plans may behave differently.
- Six seeds × 2 reps is small. A clean sweep shows `low` isn't obviously worse,
  not that the two are equal.
- Reviewers may read today's version of a file instead of the commit's. That
  affects both variants equally.
