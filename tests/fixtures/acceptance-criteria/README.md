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
| S13 | ✅ `s13-tautological-expected-value` — trigger plus **both** suppressors (literal-stated, and shape-not-value) | ✅ (shared) |
| S14 | ✅ `s14-universal-claim-existential-assertion` | ✅ (shared) |
| S15 | ✅ `s15-untouched-file-in-own-scope` — the escalated, fully mechanical form | ✅ (shared) |

Every `should-warn` fixture carries **both** a task that must warn and a task that must
not, so each case grades the suppressor as well as the trigger. A rule that only ever
gets tested on its positive case will drift into over-firing and nobody will notice
until it is being ignored.

## Status

**Run 2026-07-30. 4/4 graded verdicts correct** — every trigger fired on the intended
task, every suppressor held, and `should-pass` drew zero fires. Method: headers stripped
to a scratch copy outside the repo so each run was blind to its own answer key, one
independent pass per fixture, each applying the rule text from `plan-quality.md` in place.

**The grade was the least useful output.** The runs found five defects, and the pattern
from the audit suite held — three of four fixtures carried undeclared problems:

| Where | Defect | Fix |
|---|---|---|
| S12 rule | pattern list was **passive-voice only**; "Cancel issues no DELETE" never matched | added the active-voice alternation |
| S12 rule | listed `toBeNull`/`toBeUndefined`/`not.toHaveBeenCalled` as triggers while scoping matching to *prose bullets* — tokens it could never see. Also disagreed with S14's "stated assertion" scope | match scope now includes the assertion a bullet names, inline or in `## Implementation` |
| S12 rule | suppressor demanded a **sibling** bullet, so it fired on the correct *one-bullet* form (positive control inside the same bullet) | suppressor accepts the same bullet |
| S14 rule | suppressor discharged the *quantifier* but not the *predicate* — count-equality silenced "every status maps to a **non-empty** label", which all-`''` satisfies | suppressor must discharge the same predicate; fixture asserts per member |
| S15 rule | token list had **no subject restriction**, so "the row is unchanged" / "fields unchanged" fired. Flagged independently by three of four runs | subject must resolve to a file or path |
| `s15` fixture | both tasks `depends_on: []` while both declared the same spec file — the plan would be **refused for non-disjoint parallel branches before S12–S15 ran** | `task-legacy` now depends on `task-pup` |
| `should-pass` fixture | **one** fenced block in `## Implementation`; H7 requires two — refused before any soft rule ran, so green proved nothing | failing-test block added |
| `s12` fixture header | asserted S15 fires on "the record is unchanged" — wrong, and wrong in exactly the way the new subject restriction prevents | corrected |

Two things worth keeping from this. **`should-pass` passed for the wrong reason**: three
rules were saved by agents reading for *intent* where the literal text would have
over-fired. A suppressor that only works when the reader is charitable is not a
suppressor, and a blind run is what exposed the difference.

### Second run — S13, 2026-07-30

`s13-tautological-expected-value` added and run blind. **3/3 graded verdicts correct**,
each non-fire citing the intended suppressor. All four rules now have a `should-warn`
fixture.

This fixture carried a **pre-run hypothesis** in its header — a written prediction that
S13's suppressor 1 was too strict — recorded *before* the run so the run could confirm
or refute it independently instead of inheriting it. The run confirmed it and made it
worse than predicted: suppressor 1 and the trigger clause returned **opposite verdicts
on the same criterion**, so the outcome depended on which sentence was read second.
Suppressor 1 required the criterion's literal to be *absent* from the impl block — but
H7 *requires* the impl block to show the real value, so the clause penalised the
standard cure for tautology on nearly every correctly-written task. It now turns on what
the assertion **references** (literal vs declaration), which is what it always meant.

Three more defects, all in rules the fixture wasn't aimed at:

| Where | Defect | Fix |
|---|---|---|
| S12 | token list omitted `toBe(false)` / `toBeFalsy` / `not.toBe(true)` — *after* the rule widened its match scope specifically to see code-level tokens, so it looked at `expect(signal.aborted).toBe(false)` and ignored it | tokens added |
| S12 | matched `is null` but not `has null` / `remains null` / `stays null`. A one-word gap, and the **same under-firing family** as the passive-voice bug the previous run fixed | alternation widened |
| S12–S15 | "fire once per task" was stated for S12 only, leaving the warning count undefined for the others | stated for all four |

**Recording a prediction before the run is worth repeating.** It cost two sentences and
converted "I think this clause is wrong" into evidence — the prediction and the finding
were reached independently, which neither a re-read nor an unannotated run could have
established.

### The class fix these runs were actually pointing at

S12 was repaired by three separate runs, none aimed at it. Two of those runs asked
directly whether its pattern list was *"exhaustive-and-binding or illustrative"* — and
both times the answer was to add the missing tokens. **Three instances patched, the class
never addressed.**

The class is this: S12, S14 and S15 each stand in for a semantic concept via a finite
list of surface forms. The concept has unbounded phrasings; the list has a boundary; every
phrasing outside it is a silent miss. And the misses are found by fixtures written for
*other* rules, because a fixture written for S12 reaches for the same vocabulary as S12's
list — same author, same phrasings — so it lands inside the list and passes.

`plan-quality.md` now states that the enumerations **illustrate the shape rather than
bound it**, and that matching is on meaning, with the lists as a fast path. Triggers only:
no suppressor was loosened and S15's subject restriction is untouched. That asymmetry is
deliberate and it is what makes the widening safe — the suppressors were already semantic,
so they keep holding as the triggers widen. All five fixtures still produce their expected
verdicts under meaning-matching, `should-pass` included.

Worth carrying to any future rule here: **prefer a stated shape with examples over an
enumeration**, and when an enumeration is unavoidable, say out loud that it is not
exhaustive. Otherwise every fixture run buys one token and leaves the boundary intact.
