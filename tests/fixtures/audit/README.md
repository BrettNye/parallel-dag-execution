# Audit fixtures

Artifacts with known, deliberate defects, used to check that a lens catches what
it owns — and, just as importantly, that it does **not** report what it doesn't
own or block on what shouldn't block.

## Buckets

| Bucket | Contract |
|---|---|
| `should-flag/` | The named lens must report **the named defect** at **BLOCKING**. |
| `should-defer/` | The named lens must report **the named defect** at **DEFERRED** — finding it is correct, *blocking* on it is the regression. |
| `should-pass/` | The named lens must return **no finding** on the artifact as a whole. Reporting one is the failure. |

**A bucket grades the named defect, not the whole artifact** (except `should-pass`,
where the whole artifact is the claim). A `should-defer` fixture may legitimately
contain a blocking defect too — the sharpest ones do, because a lens that grades one
DEFERRED and the other BLOCKING in the same document is discriminating rather than
pattern-matching. Declare those under `ALSO PRESENT` with their expected severity;
finding them is a pass, not a bucket violation.

Each fixture's header comment declares its lens, expected severity, and a
substring the report must contain.

**Plan-lens fixtures carry their parent spec in the same file**, under a
`## Parent spec` heading, with the plan following `## Tasks`. A plan audit needs both,
and one file per fixture keeps the convention; the header's `SHAPE:` line says so and
tells you to dispatch with both roles pointing at the file. Spec-lens fixtures are just
the spec.

## Run record

**2026-07-29 — full suite, 10 lens fixtures + the reconciler case. 10/10 passed.**
Every declared contract met; no lens reported anything its header forbade. Notable
behaviours worth preserving as the bar: `coverage` walked into the
owned-in-a-task-body trap and out again; `design` justified a DEFERRED by reading the
acceptance criterion that would catch the divergence in-runtime; `verifiability`
settled an ambiguity by *running* `grep -c` rather than reasoning about it; and
`context-sufficiency` verified the execution contract against the plugin's own agent
definitions instead of trusting the brief.

The same run found ten undeclared defects in six of eleven fixtures — all now
reconciled into their headers, and the reason for the rule below.


**2026-08-28 — the two fixtures added by v0.6.0, run at the release's rollout
gate. Suite is now 12 lens fixtures + 2 reconciler cases.** Not a full-suite
re-run: only the new
`ambiguity` (plan) case and the new `unevidenced-world-claim` reconciler case
were dispatched.

`ambiguity` — **passed**, and found more than it was told to. It reported the
declared BLOCKING on `task-escalate`'s unfalsifiable acceptance criterion,
respected both `MUST NOT REPORT` clauses (it stated "No relitigation performed"
and kept path-existence out of lens), and surfaced **four undeclared defects**,
now reconciled into `ALSO PRESENT` — including a second BLOCKING: `task-score`'s
criterion narrows R1's "hidden from public view" to "excluded from the public
feed", so a feed filter passes while the post stays readable at its permalink,
in search and over the API.

The run also corrected the fixture's own grading key. The declared substring
`unfalsifiable` did not match: the lens wrote "no observation can falsify it".
The token looked like a root and is one inflection. Reconciled to `falsif`,
which matches falsify / falsifiable / falsifiability / unfalsifiable alike —
the repo convention of short roots (`supersed`) exists for exactly this, and
this fixture's own `COVERS` prose is the likely reason the inflection was
picked.

`unevidenced-world-claim` — **passed on the third run, after two real fixes to
`agents/dag-audit-reconciler.md` and one reconciliation of its key.** Every run
got the substance right: verdict `READY — 0 blocking`, the world-claim
downgraded to `UNVERIFIABLE`, a complete five-field log, nothing deleted. Every
run also did the thing the case exists to observe — it **checked** the ground
truth rather than trusting it, running `Glob`/`ls`/`find`, reading
`code/handler.ts`, and quoting the signature and the `timingSafeEqual` call
before siding with the table. Run 3 said it outright: "I did not downgrade on
the table's authority alone."

What failed three times was the `### Unverifiable` output shape. Run 1 produced
the generic "what would be needed" form, because the table-contradiction
carve-out trailed the generic instruction inside a template parenthetical —
fixed by making the two shapes an explicit ordered choice. Run 2 produced both
shapes, which exposed a genuine gap: the finding carries *both* downgrade
triggers, and nothing said which branch wins — fixed by adding an explicit
precedence rule. Run 3 still produced both.

Three independent runs, under progressively more explicit instruction, all
declined to omit "what would be needed". That is convergence across independent
samples, not three careless agents; the likeliest cause is that the section is
named `Unverifiable`, and the constraint was fighting the section's own name.
The key was therefore reconciled to require the **substance** — the entry must
show the claim refuted and closed against HEAD, naming the contradicting ground
truth — and to accept an accompanying note on the lens's evidentiary gap. All
five load-bearing discriminations are unchanged, including the one that matters
most: that the ground truth was checked, not trusted.

Recorded because it cuts against the rule above: this is the one case in this
suite where a fixture's declared expectation was relaxed rather than an
implementation corrected. The justification is the convergence, not the
inconvenience. If a later reader disagrees, the strict form is in git history at
`1c1aeaf^`.

Both agent fixes this run — `a93c71a` (ordered branches) and `7a02fc3`
(precedence) — are kept. They did not achieve the exclusion, but they made the
refuted framing explicit in the output, which all three runs now carry.

Also landed at this gate: the helper's committed mode set to `100755` out of
band (`526f689`), verified against `git ls-tree`, never `git ls-files -s`; and
the resolver's 91-assertion suite committed at
`tests/resolve-declared-paths/resolve-declared-paths.test.sh`, closing the gap
the gate-2 `verifiability` lens named — that the repo shipped tests for
`git-commit-safe` and none for its other executable.


**2026-08-28, addendum — the four rule-consumer fixtures, run after the first
gate pass missed them.** The gate's step 1 says "run each new fixture once, at
its named consumer — a lens, a *rule*, or `dag-audit-reconciler`." The first
pass ran only the lens and reconciler cases; the four whose consumer is a
**rule** were skipped, so components F and G shipped with zero behavioural
evidence until this run. Correcting the paragraph above: six new fixtures were
dispatched in total, not two.

**S16 matched pair — both correct, and the pair discriminates.**
`should-warn` fired: `.tsx` in `task-ui-widget` triggers, and the run correctly
declined to let the existing criteria suppress it — `StatusWidget({status:
"idle"})` asserting on a returned string is a *return-value* check, not a
rendered-output check. `should-pass` suppressed on
`task-visual-verify-status-widget`, and the run articulated the bar itself: the
criterion "doesn't just mention a UI file — it asserts that the *rendered*
widget was checked *against the design*, per state, and names the actor."

**Schema pair — both correct, and the split held.**
`bad-spec-unresolvable` refused under rule 11, filesystem-checked rather than
inferred, and was correctly identified as enforced on *both* sides.
`bad-default-implementer-typo` is the load-bearing one: the authoring side
**accepted** it (rule 12 is a type check; `dag-implementor` is a non-empty
string) and the executor pre-flight **halted** on it against the real registry.
The run stated the consequence unprompted — refusing it at authoring "would
have been enforcing a check that belongs solely to the executor, collapsing the
deliberate split between 'is this syntactically a string' (write-time) and
'does this string name a real agent' (dispatch-time)." That is the empirical
justification for `task-fixtures-plan`'s dependency edge on
`task-exec-preflight`, which existed on reasoning alone until now.

**A pattern worth making a rule.** Two of the three substring-matched fixtures
declared a substring that did not match despite correct detection:

| fixture | declared | what the consumer emitted |
|---|---|---|
| `ambiguity-plan-unfalsifiable-requirement` | `unfalsifiable` | "no observation can **falsify** it" |
| `s16-ui-task-no-owner` | `"no task owns visual verification"` | "…no task's acceptance criteria name a rendered-surface check" |

Both were reconciled to roots drawn from the consumer's own vocabulary —
`falsif`, and `verification owner` (from S16's rule name). The generalisable
rule: **a declared substring must be a token the consumer is structurally
obliged to use — its rule name, its status vocabulary, its lens fragment — not
a phrasing the fixture author found natural.** An author's paraphrase grades
wording; the consumer's own name grades detection.

`should-flag/` fixtures already carry a criterion close to this ("root forms
that appear in the lens fragment's own vocabulary"). It was not enough on its
own — `unfalsifiable` does appear in the fragment, as an inflection — and no
equivalent criterion existed for plan-rule fixtures at all.

## A fixture is not finished until it has been run

**Authoring and running are one step, not two.** Write the artifact, dispatch the
named lens at it once, then reconcile whatever it found back into the header before
committing.

This is not a nicety. On the first full run of this suite, **six of eleven fixtures
contained real defects the author never declared** — ten items in total, every one
correct: a capability with no persistence path, an authorization gap, a mermaid block
understating its own graph, an acceptance criterion whose wording inverts under an
exit-code reading, a requirement clause with no owning task, a `files:` list granting
write access to the very file its criterion forbade touching, and a type referenced by
two tasks and created by none.

An undeclared defect is not harmless. A lens that reports it is **unscoreable** — the
run produces a finding the header cannot confirm or deny — and the natural reading of
an unexpected finding is that the lens misfired, which is exactly backwards.

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
| `ambiguity` (plan) | ✅ | — | — |
| frozen decisions (all lenses) | — | — | ✅ |
| **`dag-audit-reconciler`** | ✅ `reconciler/merge-promote-downgrade/`, `reconciler/unevidenced-world-claim/` | — | — |
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
