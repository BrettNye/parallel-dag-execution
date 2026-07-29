# Plan-audit lens catalog

Seven lenses, dispatched concurrently as `dag-auditor`, one per concern. Each
fragment is pasted into the dispatch template as **YOUR LENS**.

**The spec is APPROVED and FROZEN at this gate.** No lens here may reopen a spec
design decision. The question is whether the plan *honors* the spec and whether it
will *execute safely* — not whether the spec was right. Reopening settled spec
ground is a duplicated round, and it is the single most expensive failure mode of
a two-gate pipeline.

| Lens | Concern | Default tier |
|---|---|---|
| `coverage` | requirement→task mapping; under-build and over-build | opus |
| `dag-integrity` | edges, cycles, file-scope races, `single_threaded` | standard |
| `grounding` | every assumption checked against code | standard |
| `charter` | repo invariants; named per-layer reference implementations | standard |
| `context-sufficiency` | can an implementer finish from its task body alone? | opus |
| `verifiability` | observable completion checks that a crash would not pass | opus |
| `coherence` | contradictions within the plan itself | standard |

---

## `coverage`

**coverage** — does the plan deliver the spec, exactly?

Build a **requirement→task matrix**. Enumerate every discrete spec requirement,
then name the task(s) satisfying each.

- **Under-build:** any requirement with no owning task. This is the #1 way a
  fully-green run still ships an incomplete feature. Report every one.
- **Over-build:** any task adding behavior the spec never asked for. Extra scope
  is drift, not diligence — including "while we're in there" improvements.
- **Partial coverage:** a requirement whose owning task covers only part of it.
  Say which part is uncovered.
- **Orphaned scope:** a task whose deliverable traces to no requirement at all.

Also check requirements that span tasks: where the spec asks for one behavior on
two surfaces, confirm **both** surfaces have an owner. A requirement half-owned is
an under-build that reads as covered in the matrix.

Do not evaluate whether a requirement is a good idea. That was gate 1.

---

## `dag-integrity`

**dag-integrity** — will this plan execute safely under continuous parallel
dispatch?

Check mechanically, and report each defect with the state corruption or stall it
causes:

- **Missing edges.** Any task reading, importing, or asserting against something
  another task produces MUST have a directed path to it. A missing edge is a
  nondeterministic failure that reproduces one run in five.
- **False edges.** Serialization with no data dependency — costs wall-clock for
  nothing. Report, but never at BLOCKING.
- **Cycles**, and dependencies on tasks that were cut or renamed.
- **File-scope races.** Cross-check every task's `files:`. Any two tasks that can
  run in parallel and share a `files:` entry is a race: they need an edge or a
  merge. **Verify the declared `files:` against the tree** — a path that doesn't
  exist and isn't claimed as net-new is a defect, and an understated `files:` list
  is a race the tripwire cannot see.
- **Contract surfaces.** Where one task defines a type/interface/constant that
  another consumes, confirm the edge exists. Two parallel tasks independently
  inventing the same shape is silent drift.
- **Symbol-change fallout.** For any task changing a public symbol, confirm its
  consumers are either in that task's `files:` or in a task ordered after it.
  Unowned consumers produce mid-flight cleanup rounds.
- **`single_threaded` correctness** where declared, and empty `files:` without it.

---

## `grounding`

**grounding** — is every assumption in this plan true of the code?

Apply the shared grounding rules in full, per task:

- Every path in `files:` exists, or is genuinely new — confirm the parent directory
  and that no near-duplicate already exists elsewhere.
- Every symbol, service, method, or type a task says it will call or extend exists
  **with the signature the task assumes**.
- Every injected dependency is **exported** from its module, not merely provided.
- Every "follows the existing pattern in X" claim: open X and confirm the pattern
  is what the task describes.
- Every schema/column/table assumption against the schema file or migration — not
  against the spec's description of it.
- Every test assumption: the harness, config, and command the task will run exist
  and are wired for that project.
- Any generic/shared component a task feeds new data into: read how it handles
  unknown fields.

The `NOT-FOUND` rows of your grounding table are your highest-value output — they
are the assumptions the plan is silently resting on.

---

## `charter`

**charter conformance** — will these tasks produce code that honors this repo's
rules?

Read the charter material first, then check each task. Focus on what is
*enforced* and on what is *non-obvious*:

- Layer and boundary violations that CI, the build, or runtime DI will catch.
- Placement: does each new artifact land where its consumer can reach it?
- **Named per-layer reference implementations.** Does each task point at the right
  existing file to mirror, for its layer? A blanket "follow the existing pattern"
  is a finding; so is a reference pointing at a spec instead of code; so is a
  reference that is the wrong one of several similar candidates.
- Barrel and export conventions — under explicit named re-exports, a new file is
  invisible until the barrel is edited.
- The repo's actual tooling commands for migrations, codegen, and tests.
- Recurring bug classes listed in `.claude/audit-charter.md`, if present.

**Verify enforcement before grading BLOCKING** — read the lint/CI config. An
unenforced convention is drift (DEFERRED), not a build failure.

---

## `context-sufficiency`

**context-sufficiency** — can each task be completed by an implementer who sees
**only its own body plus its immediate dependencies' output**, and never the spec,
the charter, or the rest of the plan?

That is the actual execution contract. Audit against it:

- Requirements referenced by pointer ("per spec §4", "upholds Charter I2",
  "as described above") rather than **inlined**. The reviewers treat the task body
  as the binding spec and never see the referenced document, so a bare pointer is
  unverifiable at review time.
- Acceptance criteria that assume knowledge from a sibling task the implementer
  cannot see.
- Elided siblings — "the other three follow the same shape", a trailing "etc.",
  or "per §X" standing in for content. Enumerate the implied siblings and confirm
  each exists **with verifiable content**, not a hollow stub.
- Tasks whose stated file scope cannot actually accommodate the described work.
- Tasks too large to implement and review in one pass; and trivially-splittable
  serial chains that could parallelize.

Each finding should name what the implementer would have to guess.

---

## `verifiability`

**verifiability** — does each task state how its completion is checked, and would
that check actually catch failure?

For every task, find the stated completion check, then attack it:

- **No observable check at all** — "done when implemented" is not a check.
- **Tautological** — asserting a constant against the same constant the
  implementer will type.
- **Passes on a crash** — "no row written", "field is undefined", "does not call
  X" all pass if the code throws on line 1. Ask of every assertion: *would this
  pass if the function under test threw immediately?* If yes, demand a positive
  companion proving the observation channel works.
- **A diff property, not a behavior** — "file X is untouched" is testable only as
  positive-with-control.
- **Blind to the mechanism** — a spy that cannot see the attribute the requirement
  is about; a unit test for something only integration can prove.
- **Not DOM-driven where the behavior is a template binding** — a spec calling
  `component.doThing()` leaves click handlers and model bindings unpinned;
  two-way binding is two bindings. Enumerate the bound surfaces each task adds.
- **Green-but-crashed gates** — a build or check command that can report success
  after its checker died.

Also flag tasks whose check requires infrastructure that may be absent (docker, a
live DB): the task must **report the absence** rather than claim green.

---

## `coherence`

**coherence** — contradictions WITHIN the plan document itself. Compare the plan
only against ITSELF (spec-vs-plan mismatches belong to `coverage`).

Hunt for:

- Two tasks stating incompatible things about the same file, type, or contract.
- A later task silently overriding an earlier task's decision, with no marker at
  the earlier point of claim.
- The mermaid block, ASCII tree, or task-count summary disagreeing with the actual
  task list and `depends_on` edges.
- `files:` frontmatter disagreeing with the paths named in that task's body.
- Naming drift — one concept under two names across tasks, or one name for two
  concepts.
- Task ids referenced in prose that don't exist, or that were renamed.
- A plan-level default contradicted by a per-task override that looks unintentional.
- An acceptance criterion the task's own stated implementation cannot satisfy.

Quote both passages with their task ids. State which is intended, or declare it
**undecidable as written** and force the author to choose.
