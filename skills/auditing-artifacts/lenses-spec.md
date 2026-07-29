# Spec-audit lens catalog

Six lenses, dispatched concurrently as `dag-auditor`, one per concern. Each
fragment below is pasted into the dispatch template as **YOUR LENS**. The
auditor supplies the shared machinery (charter loading, grounding rules, severity
taxonomy, output format) — do not repeat it here.

| Lens | Concern | Default tier |
|---|---|---|
| `absence` | requirements implied but never stated | opus |
| `ambiguity` | stated requirements with more than one reading, or no observable outcome | opus |
| `grounding` | does the spec's picture of the current system match the code? | standard |
| `charter` | repo conventions, boundaries, invariants, placement | standard |
| `coherence` | contradictions within the spec itself | standard |
| `design` | DRY / SRP / SoC / reuse — **DEFERRED unless a concrete failure is named** | opus |

Adding a lens is a row here plus a fragment below. It is not a new agent.

---

## `absence`

**absence** — requirements that are implied but NEVER STATED. Absence is the most
dangerous kind of finding and the hardest to see, because there is no text to
react to.

Hunt specifically for unstated:

- Error and failure paths. What happens when the write fails, the lookup returns
  nothing, the upstream field is missing or null?
- Empty / zero / boundary inputs. Empty string, zero rows, one row, the maximum.
- Concurrency and ordering. Two users editing the same record; an event arriving
  out of order; a stale client overwriting a newer value.
- Idempotency and replay. What if the same action fires twice?
- Permission and scope. Who may do this? What happens cross-tenant? **If a guard
  exists on a sibling path, does it exist on this one — and is it enforced
  server-side or only in the client?**
- Migration/backfill for existing rows when a new column appears.
- Timezone and date-format handling wherever a date crosses a boundary.
- Navigation and aftermath of a state-changing action — where does the user land,
  and is there an inverse operation?
- Cache invalidation when a new read path appears.
- Tie-breaking wherever the spec says "ordered" but the sort key is not unique.

You may read code to establish that a case is REACHABLE — that is what makes it a
finding rather than a hypothetical. Cite `file:line` when you do. Your subject is
the spec's **silence**, not the accuracy of claims it does make.

**Also check the spec's own risk section against itself.** Where the spec states
a blast radius for an assumption it admits is unverified, verify that stated
blast radius. An understated one is a blocking finding.

---

## `ambiguity`

**ambiguity + testability** — two halves, both about requirements that ARE stated.

**(1) Build a requirement inventory first.** Enumerate every discrete
must/should/shall as an atomic, numbered requirement. Then for each ask: is there
exactly one reading? Quote the sentence and state the divergent readings
explicitly. Targets: vague quantifiers ("appropriate", "as needed", "handles it
correctly"), unspecified ordering, unspecified formatting, undefined terms, and
any phrase like "the existing X" where more than one X exists.

**(2) Testability.** For each requirement ask: *what observable behavior proves
this is done?* Flag any requirement with no assertable outcome. Specifically flag
requirements whose only plausible test would be:

- **tautological** — asserting a constant against the same constant the
  implementer will type;
- **an absence assertion that passes on a crash** — "no row written", "field is
  undefined", "does not call X" all pass if the handler throws on line 1. Demand a
  positive companion proving the observation channel works at all;
- **a diff property, not a behavior** — "X is untouched" is testable only as
  positive-with-control: the new thing is absent *in a test that also finds it
  present somewhere it should be*;
- **blind to the real mechanism** — a spy that cannot observe the attribute the
  requirement is actually about.

Where the spec describes UI behavior, note whether the observable outcome is
DOM-driven. A test calling a component method directly leaves click handlers and
model bindings unpinned; two-way binding is two bindings. Enumerate **every**
template-bound surface the spec adds and say which ones lack a stated DOM-level
test.

---

## `grounding`

**grounding** — does the spec's picture of the CURRENT system match the code?

For every claim about existing code — a method name, a signature, a schema shape,
a table or column, an existing behavior, a "this already exists" or "X already
does Y" assertion, a cited file path or line — verify it against the repository.

Apply the shared grounding rules in full. In addition:

- Where the spec says work is needed, check whether it **already happens** on the
  path in question. A "we must add a second query" claim is wrong if the first one
  already fetches the data.
- Where the spec cites a line number, verify the line.
- For dependency-injection frameworks, verify a provider is **exported** from its
  module, not merely provided — provided-but-not-exported is a boot-time failure
  invisible to build and test.
- For any shared/generic component the spec feeds new data into, read that
  component's own handling of unknown fields. Auto-inference of columns, keys, or
  bindings from payload shape is a common silent-behavior source.
- Check the spec's stated verification gates actually verify. A gate that can
  report success after its checker crashed is not a gate.

---

## `charter`

**charter conformance** — does the spec violate THIS REPO's documented
conventions, architectural boundaries, and hard invariants?

Read the charter material first (see the auditor's Charter section), then check
the spec against it. Pay particular attention to:

- Layer and boundary violations — which layer may own what; whether a lib may
  depend on a framework; where shared types belong.
- Whether the spec puts code somewhere a required consumer **cannot reach at
  runtime** — a constant needed by two separate runtimes with no shared import
  path, a map in a lib the server can't import.
- Whether it proposes a new helper/type/constant where the repo has a canonical
  home or an existing equivalent.
- **Named per-layer reference implementations.** Does the spec point at the right
  existing example to mirror, per layer? A blanket "follow the existing pattern"
  with no named file is a finding — and a reference pointing at another *spec*
  rather than at code does not satisfy it. Verify the named reference is the right
  one; "mirror the existing dialog" is wrong if there are three and they differ.
- Tooling and migration commands: does the spec name the repo's actual command?
- Barrel and export conventions for the directories it touches. **Check whether
  the barrel uses `export *` or explicit named re-exports** — under the latter, a
  new file is invisible to consumers until the barrel is edited, and the import
  simply fails to resolve.

**Before grading a layering violation BLOCKING, verify the enforcement actually
exists** — read the lint/CI config rather than assuming. An unenforced convention
costs drift, not a build failure, and grades DEFERRED.

---

## `coherence`

**coherence** — contradictions WITHIN this one document. You compare the document
only against ITSELF.

Hunt for:

- Two sections stating incompatible things — a field named one way in §3 and
  another in §7; a decision made in one section and silently overridden later.
- A later amendment that supersedes an earlier claim **without an inline marker at
  the point of claim**. A reader who stops at the earlier section is misled. This
  is a real defect, not a style nit.
- A section presenting as established fact something a later section admits is an
  unverified assumption.
- Naming drift — one concept under two names, or one name for two concepts.
- Tables, layer maps, or file lists that disagree with their prose.
- Cross-references pointing at the wrong section, or one that doesn't exist.
- A stated invariant that another part of the same document violates.
- Contradictory ordering or sequencing claims.
- **An acceptance test the document's own stated semantics cannot satisfy.**

Quote BOTH conflicting passages with their sections, and state which you believe
is intended — or declare it **undecidable as written** and force the author to
choose. Do not guess; a guessed resolution becomes the next round's finding.

---

## `design`

**design soundness** — DRY, Single Responsibility, Separation of Concerns,
reuse-over-reinvent, judged on the APPROACH the spec commits to.

**Read this constraint before you start.** Your findings default to **DEFERRED**.
You may propose BLOCKING **only** if you name the concrete failure: a compile
error, a runtime crash, a boot-time DI failure, an enforced CI check, data
corruption, or two copies that WILL silently drift because no shared import path
exists between them. "This is duplicated", "this violates SRP", "this would be
cleaner", and "best practice says" are DEFERRED, always. A finding you cannot
attach a concrete failure to is still worth reporting — as DEFERRED.

This constraint exists because your lens has an unbounded supply of arguable
findings, and unbounded findings with gating power produce endless revision
cycles. Surface real structural risk; do not maximize finding count.

Hunt:

- **Reuse over reinvent.** Does the spec hand-roll what the repo already provides?
  Check the shared libs before accepting any new helper as necessary, and cite the
  existing thing.
- **DRY with a real drift mechanism.** Two definitions of one constant across two
  runtimes with no shared import is concrete. Two copies in one runtime that could
  share an import is DEFERRED.
- **Widening a shared base type.** Check every extender and every construction
  site before accepting it — a required field on a shared base breaks producers in
  domains that have nothing to do with this feature, and forces unrelated code to
  fabricate a value.
- **SRP.** Any proposed unit carrying more than one reason to change.
- **SoC / placement.** Business logic in a data-access or adapter layer;
  presentation formatting in a repository; a lib holding what only one app needs.

Cite `file:line` for anything you claim already exists. An uncited reuse claim is
dropped. If reuse would create worse coupling than a second copy, say so — the
finding is then to **note the divergence deliberately**, not to force reuse.
