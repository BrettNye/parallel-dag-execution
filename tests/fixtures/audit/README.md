# Audit fixtures

Artifacts with known, deliberate defects, used to check that a lens catches what
it owns — and, just as importantly, that it does **not** report what it doesn't
own or block on what shouldn't block.

## Buckets

| Bucket | Contract |
|---|---|
| `should-flag/` | The named lens must report the defect at **BLOCKING**. |
| `should-defer/` | The named lens must report the defect at **DEFERRED** — finding it is correct, *blocking* on it is the regression. |
| `should-pass/` | The named lens must return **no finding**. Reporting one is the failure. |

Each fixture's header comment declares its lens, expected severity, and a
substring the report must contain.

**Plan-lens fixtures carry their parent spec in the same file**, under a
`## Parent spec` heading, with the plan following `## Tasks`. A plan audit needs both,
and one file per fixture keeps the convention; the header's `SHAPE:` line says so and
tells you to dispatch with both roles pointing at the file. Spec-lens fixtures are just
the spec.

**A fixture scores only the lens named in its `LENS:` line.** Run other lenses
against it and you are exercising the harness, not grading them — their findings
have no declared expectation to check against, so neither a hit nor a miss means
anything. Two consequences worth knowing:

- A fixture may contain **undeclared real defects** that other lenses correctly
  find. That is not a fixture failure; it is a fixture that under-documents itself.
  When it happens, add the defect to the header under `ALSO PRESENT` with its
  expected severity per lens, so the next run is scoreable
  (`should-flag/coherence-superseded-no-marker.md` carries a worked example).
- Never audit a fixture with steps 6 and 9 of `auditing-artifacts` enabled. Writing
  an `## Audit record` into a fixture rewrites the input, and some fixtures
  deliberately carry one while others deliberately do not. The skill has a
  read-only path for exactly this; use it.

## Why `should-defer` exists

The severity gate is the highest-leverage rule in this design and the easiest to
regress: an unbounded criterion that regains gating power reintroduces endless
revision cycles. A `design` lens that correctly notices duplication but marks it
BLOCKING without naming a concrete failure has failed the fixture, even though its
observation is true.

## Why `should-pass` exists

A lens that always finds something is a lens that has stopped discriminating.
These fixtures pin the cases where silence is the correct answer: a frozen
decision, an already-listed empirical unknown, a defect another lens owns.

## Coverage

| Lens | should-flag | should-defer | should-pass |
|---|---|---|---|
| `coherence` (spec) | ✅ ×2 | — | — |
| `grounding` (spec) | ✅ | — | — |
| `design` (spec) | — | ✅ | — |
| `coverage` (plan) | ✅ | — | ✅ |
| `verifiability` (plan) | ✅ | ✅ | — |
| `context-sufficiency` (plan) | ✅ | — | — |
| `dag-integrity` (plan) | ✅ | — | — |
| frozen decisions (all lenses) | — | — | ✅ |
| **`dag-audit-reconciler`** | ✅ `reconciler/merge-promote-downgrade/` | — | — |
| `absence`, `ambiguity` (spec) | ❌ none yet | ❌ | ❌ |
| `charter` (spec + plan) | **n/a — see below** | n/a | n/a |

**Two lenses carry a matched pair, and those are the strongest rows.** `coverage` has
a should-flag *and* a should-pass, so it is graded in both directions — a lens that
manufactures gaps fails one, a lens that misses them fails the other. `verifiability`
has a should-flag and a should-defer covering the *same weakness class*, distinguished
only by whether a concrete failure exists. Single-direction rows can only catch
under-reporting.

**`charter` is not fixture-testable, and that is a conclusion rather than a backlog
item.** Its entire job is reading a *real* charter and *real* enforcement config — a
synthetic fixture would need a fake `CLAUDE.md` and a fake lint config, and would then
be grading the lens against a fake repo rather than against anything true. Its
validation is per-repo: point it at a tree with an `audit-charter.md` and check that it
reads the enforcement config *before* grading severity. Observed doing exactly that on
two real repos, including catching a `.dependency-cruiser.cjs` comment that contradicted
its own rule body.

The reconciler has its own harness — see [`reconciler/README.md`](reconciler/README.md).
It cannot be graded by a single-artifact fixture, because its inputs are N lens
reports, and its failures are *absences*: a dropped finding, a promotion never made,
a contradiction collapsed by vote, a downgrade with no logged reason. None of those
look wrong on the page, which is why it needs a case with known answers.

**The ❌ rows are real gaps, not "covered by the others."** The fixtures present
encode the bug classes with observed recurrence; the rest are unwritten. Do not read a
green fixture run as full lens coverage.

**There is no runner, and that caps how many fixtures are worth having.** Each is
scored by hand — dispatch the lens, read the output, compare to the header. Six
fixtures that get run beat fifteen that do not, so prioritise by regression risk
(the severity gate, the "no findings is valid" affordance) over filling in the table.

## Running

These are prompt-level fixtures, not unit tests — a lens is a model dispatch, so
there is no assertion harness. Run one by dispatching `dag-auditor` with the named
lens against the fixture and checking the report against the header's expected
severity and substring. Mechanical assertions would only pin wording, which is not
what the fixture is about.
