# Spec reviewer at `effort: low` vs `medium`: results

## Recommendation: keep `dag-spec-reviewer` at `effort: medium`

`low` failed the experiment's pre-set rule. In one of 12 seeded-defect runs, it returned
**APPROVED** on a commit that was missing a required sentence. Both `medium` runs on the same
seed caught it. The rule requires `low` to catch every seed run that `medium` catches, so it fails.

The token saving would also be negligible:

| `subagent_tokens` (29 runs per variant) | medium | low | low vs medium |
|---|---|---|---|
| Median per run | 13,048 | 12,929 | **−0.91%** |
| Total | 414,334 | 409,461 | **−1.18%** |

In paired runs (same case, same rep), `low` used fewer tokens 17 times and more 12 times. The
median paired difference was −78 tokens per review.

**What was tested.** The plugin's spec reviewer checks each finished task against its written
spec. It is the only check for "built too little" or "built something not asked for". The
experiment replayed 17 real past tasks from this repo through two copies of the reviewer that differ
only in `effort:`:

- 14 tasks presumed clean (C01–C14).
- 3 tasks a later commit had to patch (R01–R03), reported only.
- 6 "seeded" tasks (S01–S06). Each is a clean task's real commit with one deliberately planted
  spec violation.

All reviews ran on `model: "sonnet"`. A reviewer that misses a planted violation would pass a bad
task in a real run, so the seeds decide the result.

## Decision rule (from the README, applied as written)

| Condition | Result |
|---|---|
| (a) every seed run caught at `medium` was also caught at `low` | **Fails**: S03 rep 2 was caught at `medium` but missed at `low` |
| (b) `low` has no more false positives on C01–C14 than `medium` | Holds: 0 false-positive runs for each variant |

Both conditions must hold to recommend `low`, so the recommendation is to stay at `medium`.

## Run integrity

- **Runs:** 58 of 58 completed: 29 per variant, made up of 14 C, 3 R and 6×2 S runs each. None
  errored or returned empty, and none were re-dispatched.
- **Prompts:** built mechanically from the template in `skills/executing-dag-plans/spec-reviewer-prompt.md`
  and saved in `prompts/`. Each prompt the reviewer actually received was extracted from its
  transcript and compared byte for byte with the saved file: **58/58 matched**. Both variants got the
  identical prompt for each case. No prompt mentions the experiment, effort, seeds or expected answers.
- **Raw reports:** `raw/<run-id>.md` holds each reviewer's final report verbatim, taken from its
  transcript.
- **Per-run numbers:** `runs.csv` has `subagent_tokens`, `tool_uses` and `duration_ms` for each run,
  taken from the task-notification usage block.
- **Seeded commits:** built locally by `build-seeds.sh`, with SHAs in `seed-shas.txt`. They were not
  pushed.
- **Answer key:** `answer-key.md` was read only after all 58 runs were recorded in `runs.csv`.
- **Two verdicts needed a judgment call.** Both are `low` runs, and both are explained below.
  - S01-low-2 opens with "APPROVED", then corrects itself and ends with "Revised verdict: ISSUES".
    `runs.csv` records its final verdict, ISSUES.
  - S03-low-2 states only "APPROVED", though its body describes the gap. `runs.csv` records APPROVED.

## Per-seed catch table

A run **catches** a seed only if it returns ISSUES and one issue names the planted defect, per
`answer-key.md`.

| Seed | Planted defect | medium-1 | medium-2 | low-1 | low-2 |
|---|---|---|---|---|---|
| S01 (C03) | under-build: "rewire `depends_on:`" line lacks `H9` | ✅ | ✅ | ✅ | ✅* |
| S02 (C12) | over-build: enum written `merged \| split \| auto` | ✅ | ✅ | ✅ | ✅ |
| S03 (C08) | under-build: reviewer tier-resolution sentence removed | ✅ | ✅ | ✅ | ❌ **APPROVED** |
| S04 (C07) | over-build: extra "Modify implementer" table row | ✅ | ✅ | ✅ | ✅ |
| S05 (C01) | wrong value: S8 threshold `≥2 files` instead of `≥3` | ✅ | ✅ | ✅ | ✅ |
| S06 (C09) | over-build: ISSUES format gains `\| Severity: …` | ✅ | ✅ | ✅ | ✅ |
| **Caught** | | **6/6** | **6/6** | **6/6** | **5/6** |

Overall, `medium` caught 12 of 12 seed runs and `low` caught 11 of 12.

\* S01-low-2 counts as a catch only because of its self-correction. Its first line is
"APPROVED. Commit c2c177d meets the spec…", and its last section is "Revised verdict: ISSUES." A
controller that reads only the leading verdict would have passed this commit. Under that reading,
`low` caught 10 of 12. Every `medium` report opens with the verdict it ends with.

### The miss: S03-low-2

The S03 commit drops this sentence: "Dispatch the spec reviewer with `model: resolve_model(...)`
… and the quality reviewer with … Reviewer tiers fall back …". Step 3 of the task explicitly
requires it.

S03-low-2 (verdict APPROVED):
> APPROVED. Commit a2d482ef touches only skills/executing-dag-plans/SKILL.md and meets every step of Task 5 with no over-build. I read the diff and did not run the Step 4 grep.
> …
> - **Step 3, reviewer dispatch:** partially met. … It does not add the spec-reviewer and quality-reviewer `model: resolve_model(resolve_tier(task, 'spec_reviewer'))` / `'quality_reviewer'` sentence or the per-task → plan-level default → `standard` fallback for reviewers.

S03-medium-2 (verdict ISSUES, same commit):
> **ISSUES**
>
> 1. Requirement: Step 3 says to add reviewer tier resolution to §Per-task review chain. … Actual: The diff adds only the sentence "Review-issue re-dispatch of the **implementer** uses the original resolved implementer tier …". The spec reviewer and quality reviewer dispatch sentences are absent, and so is the fallback chain statement.

The `low` reviewer noticed the gap but still returned APPROVED. Both runs whose stated verdict
contradicts their own findings are `low` runs (S03-low-2 and S01-low-2). None of the 29 `medium`
reports does this.

## Clean cases C01–C14

The two variants returned the same verdict on all 14 cases: APPROVED on 12, and ISSUES on C06
and C09.

| Case | medium | low | Adjudication of each ISSUES |
|---|---|---|---|
| C01–C05 | APPROVED | APPROVED | — |
| C06 | ISSUES | ISSUES | **Real (minor)**: see below |
| C07, C08 | APPROVED | APPROVED | — |
| C09 | ISSUES | ISSUES | **Real**, plus one unfounded item in the `medium` report: see below |
| C10–C14 | APPROVED | APPROVED | — |
| **False-positive runs** | **0** | **0** | |

- **C06 (token-opt Task 3), both variants.** Both flag that the commit changed "H1-H6" to "H1-H9"
  in the `plan-quality.md` bullet. Step 1 asked only for "S1-S6" → "S1-S9" there.
  - This is **real**: the diff includes an edit the spec doesn't ask for. It corrects stale text
    and is harmless, but under the bidirectional rule it is over-build.
  - The two reports are nearly identical. medium: "The spec doesn't ask for this."
    low: "This is an unrequested edit, so it is over-build."
- **C09 (token-opt Task 7), both variants.** Both flag that Step 3's verify command
  `grep -nE "…|Stable preamble"` matches only the Agent example.
  - This is **real**. I re-ran that grep against the commit and it returns only line 72, because
    the preamble label is lowercase "stable preamble".
  - `medium` also lists a second formal issue: the template has no "project conventions"
    placeholder. This item is **unfounded**. The pre-commit template had no such section (zero
    occurrences), the task says "(2) project conventions **if any**" and "Semantic content
    unchanged", and the dispatch template documents conventions as optional.
  - `low` raised the same point and an HTML-comment "minor over-build" only as informal
    "Other points", not as formal issues.
  - At the issue level, `low` had one fewer unfounded formal item than `medium`. At the run level,
    neither variant has a false positive. Rule (b) holds either way.

## Follow-up cases R01–R03 (report only)

These are real commits that a later commit patched. They don't count toward the decision.

| Case | Later fix (from answer key) | medium | low |
|---|---|---|---|
| R01 | 3b0b721: remove novelty-regex word from s9-security fixture body | **ISSUES**: names exactly that word ("cryptographically") | APPROVED |
| R02 | df28c5d: use tests/data path so s10-fixture-only matches the S10 glob | APPROVED, but notes the glob mismatch and dismisses it | APPROVED |
| R03 | e20fe91: disambiguate H10 detection clause | ISSUES, on a different point: step 2 reads "H1-H10" not "H1-H11" | APPROVED (notes the same H1-H10 point, dismisses it) |

On R01, only `medium` found the defect that was later fixed by hand. On R02, `medium` saw the
later-fixed defect but chose not to raise it. On R03, neither variant found the later fix's
subject. These cases don't count, but they point the same way as the seeds.

## Every disagreement between the variants

There are three verdict-level disagreements. All three are cases where `medium` said ISSUES and
`low` said APPROVED. There is none in the other direction.

**1. S03 rep 2 (seed).** Quoted in full above. `medium` returned ISSUES naming the missing sentence.
`low` described the gap and still returned APPROVED.

**2. R01.**
- medium (ISSUES):
  > Actual: in …/s9-security-no-opus.md, the task body says "Produces a cryptographically random token". "cryptographically" contains "cryptographic", which is in the S9 novelty-signal regex. So pattern (2) also fires … and S9 no longer matches the fixture's EXPECTED comment.
- low (APPROVED):
  > `s9-security-no-opus.md`: `files: [src/auth/session.ts]`, no `quality_reviewer_hint`.
  > …
  > **Over-build:** None.

**3. R03.**
- medium (ISSUES):
  > Requirement: Step 4 says to change §Detection algorithm step 2 to run "hard rules H1-H11" … Actual: In commit f7b2bae, step 2 reads "Run hard rules H1-H10." The note is present, but the range is wrong.
- low (APPROVED):
  > The spec literally says "H1-H11", but H11 did not exist in that commit's table. … so I treated the commit's "H1-H10" as consistent at that point and not an issue.

There are also two differences within matching verdicts:

- **S01 rep 2.** `low` reaches ISSUES only after first declaring "APPROVED. Commit c2c177d meets
  the spec…". `medium` opens with "ISSUES".
- **C09.** Both variants return ISSUES. `medium` adds the unfounded project-conventions item as a
  formal issue, and `low` mentions it only as a side note.

## Cost and time detail

| Subset | n per variant | Median tokens (medium / low) | Total tokens (medium / low) | Total Δ |
|---|---|---|---|---|
| All | 29 | 13,048 / 12,929 | 414,334 / 409,461 | −1.18% |
| C01–C14 | 14 | 13,089 / 13,091 | 207,196 / 205,314 | −0.91% |
| S01–S06 | 12 | 12,005 / 11,690 | 151,414 / 148,875 | −1.68% |
| R01–R03 | 3 | 18,776 / 18,557 | 55,724 / 55,272 | −0.81% |

- **Tool uses:** mean 2.48 for medium and 2.38 for low.
- **Duration:** total `duration_ms` was 289,377 for medium and 273,153 for low (−5.6%). The median
  per run was 8,567 for medium and 8,749 for low. Durations are wall-clock times for runs executed
  10 at a time, so they are noisy.

`subagent_tokens` appears to be dominated by fixed context: the system prompt, the agent body, the
task spec and the diff. The difference between effort levels is a small slice of it. That explains
why the saving is about 1%.

## Limits of the test

- **Domain.** All tasks are markdown skill edits from this repo. Spec review on code-heavy plans may
  behave differently.
- **Sample size.**
  - The seed result rests on 12 runs per variant. The decisive difference is a single run, so this
    is weak evidence that `low` is worse. However, the rule is asymmetric by design: one miss is
    enough to block the change.
  - The C and R cases had 1 rep per variant, so the clean-case agreement is not a variance estimate.
- **Verdict parsing.** The "catch" count depends on how a verdict is read.
  - S01-low-2 counts as a catch only on its trailing "Revised verdict". A controller keying on the
    first word would score `low` at 10/12.
  - S03-low-2 is a miss under any reading, because it never states ISSUES.
- **Working tree.** Reviewers ran against today's working tree, where the files have moved on
  since these commits. Several reports mention HEAD content (for example R03-medium and
  C03-medium/low). That affects both variants equally, as the README notes.
- **Model.** Every run used `model: "sonnet"`. The effect of `effort:` may differ on other models
  or tiers.
- **Token metric.** `subagent_tokens` is the harness's per-subagent total, recorded as reported. I
  did not break it into input, output or cached tokens.
- **Scope.** `agents/`, `skills/`, `cases/`, `seeds/` and `answer-key.md` were not modified.
  `agents/dag-spec-reviewer.md` still pins `effort: medium`.
