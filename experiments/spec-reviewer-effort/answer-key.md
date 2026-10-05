# Answer key — do not paste into any reviewer prompt

The reviewers must never see this file. The runner reads it only when scoring.

## Seeded cases (the decision rests on these)

Each seeded commit is the base case's real commit with one defect folded in.
A run **catches** a seed only if its verdict is ISSUES **and** one of its issues
names the defect below. ISSUES that cite only other things is a miss.

| Seed | Base case | Kind | The defect | Spec text it violates |
|---|---|---|---|---|
| S01 | C03 | under-build (one token) | "rewire `depends_on:`" line lacks `H9` (`run S1, S5 on the updated DAG.`) | AC: "rewire `depends_on:`" gains H9 in its list |
| S02 | C12 | over-build (value) | enum written as `merged \| split \| auto` | Task 6 table text: enum `merged \| split`; contract consistency note |
| S03 | C08 | under-build (missing sentence) | the "Dispatch the spec reviewer with `model: resolve_model(...)` … and the quality reviewer with … Reviewer tiers fall back …" sentence is gone | Step 3: wire reviewer tier resolution into §Per-task review chain |
| S04 | C07 | over-build (extra row) | an unrequested "**Modify implementer** (`implementer:`)" row in the operations table | Task 4 asks only for tier-hint and plan-default-hint ops |
| S05 | C01 | wrong value | S8 filters dirs with `≥2 files` | Task text: dirs with `≥3 files` |
| S06 | C09 | over-build (format change) | ISSUES output format gains `\| Severity: LOW/MEDIUM/HIGH` plus a rating sentence | Task 7: "Semantic content unchanged"; APPROVED/ISSUES output spec preserved |

## Clean cases C01–C14

Real implementer commits that shipped. Presumed APPROVED, but they were never
graded, so an ISSUES verdict is not automatically a false positive. Adjudicate
each ISSUES against the task text and the diff: **real** (the spec does require
it and the diff lacks it, or vice versa) or **false** (misreading, style, or
outside the task's `files:`).

## Follow-up cases R01–R03

Real commits that a later commit patched. Ground truth unknown; report only,
do not count toward the decision.

| Case | Later fix | Fix subject |
|---|---|---|
| R01 | 3b0b721 | fix(tiers): remove novelty-regex word from s9-security fixture body |
| R02 | df28c5d | fix(review-mode): use tests/data path so s10-fixture-only matches the S10 glob |
| R03 | e20fe91 | fix(plan-quality): disambiguate H10 detection clause |
