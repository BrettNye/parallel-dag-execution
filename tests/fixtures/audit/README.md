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
| `verifiability` (plan) | ✅ | — | — |
| `dag-integrity` (plan) | ✅ | — | — |
| `design` (spec) | — | ✅ | — |
| frozen decisions (all lenses) | — | — | ✅ |
| `absence`, `ambiguity`, `charter` (spec) | ❌ none yet | ❌ | ❌ |
| `coverage`, `context-sufficiency` (plan) | ❌ none yet | ❌ | ❌ |
| **`dag-audit-reconciler`** | ✅ `reconciler/merge-promote-downgrade/` | — | — |

The reconciler has its own harness — see [`reconciler/README.md`](reconciler/README.md).
It cannot be graded by a single-artifact fixture, because its inputs are N lens
reports, and its failures are *absences*: a dropped finding, a promotion never made,
a contradiction collapsed by vote, a downgrade with no logged reason. None of those
look wrong on the page, which is why it needs a case with known answers.

**The ❌ rows are real gaps, not "covered by the others."** The fixtures present
encode the bug classes with observed recurrence; the rest are unwritten. Do not
read a green fixture run as full lens coverage.

## Running

These are prompt-level fixtures, not unit tests — a lens is a model dispatch, so
there is no assertion harness. Run one by dispatching `dag-auditor` with the named
lens against the fixture and checking the report against the header's expected
severity and substring. Mechanical assertions would only pin wording, which is not
what the fixture is about.
