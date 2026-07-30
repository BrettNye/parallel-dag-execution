# Acceptance-criteria fixtures (S12–S15)

Fixtures for the four soft heuristics that ask whether an acceptance criterion can
**fail** — `plan-quality.md` S12–S15. Same buckets as the other plan-quality fixture
suites: `should-warn/` and `should-pass/`.

## Why these four exist

H4 checks that a task **has** acceptance criteria. Nothing checked that they can fail.
On the one plan where audit findings were scored against the commits that *actually*
caused rework, every rework commit was an AC-falsifiability defect and none was an
H-rule finding.

So these rules exist to move the four **recurring** shapes out of a `verifiability`
lens dispatch (~130k tokens) and into the authoring pass (free). The lens still owns
the novel cases — a spy blind to the real mechanism, an assertion a normalizing
library defeats, a gate that reports success after its checker died.

## The suppressor is the point

Each shape has a legitimate form:

| Rule | Fires on | Suppressed by |
|---|---|---|
| S12 | a negative outcome with no positive companion | a sibling bullet exercising the same channel positively |
| S13 | an expected value sourced from the declaration under test | the value stated as a literal, or a known-good vector |
| S14 | a universal claim proved existentially | iterating an exported set, or count-equality |
| S15 | a property of the commit, not of behaviour | positive-with-control, and not self-scoped |

**A rule that fires on the correct form is worse than no rule**, because it teaches
authors to skip the whole class. That is why `should-pass/clean-falsifiable-criteria.md`
deliberately contains **every trigger word** in its legitimate form — if any of the four
warns there, it is matching words instead of shapes.

## Coverage

| Rule | should-warn | should-pass |
|---|---|---|
| S12 | ✅ `s12-absence-no-positive-companion` | ✅ (shared) |
| S13 | ❌ none yet — it is an LLM-judgment rule like S1, and the honest fixture is harder to write than the others | ✅ (shared) |
| S14 | ✅ `s14-universal-claim-existential-assertion` | ✅ (shared) |
| S15 | ✅ `s15-untouched-file-in-own-scope` — the escalated, fully mechanical form | ✅ (shared) |

Every `should-warn` fixture carries **both** a task that must warn and a task that must
not, so each case grades the suppressor as well as the trigger. A rule that only ever
gets tested on its positive case will drift into over-firing and nobody will notice
until it is being ignored.

## Status

**Authored 2026-07-30, not yet run.** Per `tests/fixtures/audit/README.md`, a fixture is
not finished until it has been run once and its output reconciled into the header — six
of eleven fixtures in the audit suite carried undeclared defects on their first run. Treat
these four as unvalidated until that happens.
