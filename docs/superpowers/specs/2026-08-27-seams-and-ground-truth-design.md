# Repo Seams and Ground Truth — Design Spec

**Date:** 2026-08-27
**Target:** `parallel-dag-execution` v0.5.0 → v0.6.0
**Skills targeted:** `auditing-artifacts`, `executing-dag-plans`, `writing-dag-plans`. Plus two agent definitions, one new shipped helper, and conformance fixtures.

**Motivation:** an audit/execution history on one consumer repo. That history is cited as evidence throughout and **no part of it is embedded as plugin content** — see Non-goals.

## Goal

Two gaps, one principle.

1. **Implementers and reviewers read nothing repo-specific.** Auditors get `.claude/audit-charter.md`; the four execution-side roles get generic discipline only. In a repo where the obvious verification command produces a false green, a generic verification skill reliably reaches for the wrong gate and reports done.
2. **Lenses answer questions about the world by reading rather than resolving.** Measured: two of seven lenses at gate 2 and two of six at gate 1 reported charter/docs files **absent when both existed**. Nothing made them look.

## Why: prose goes stale, implementation is true north

Every rule this plugin ships is prose executed by a model. That is correct for *judgment* and wrong for *facts*.

The distinction is load-bearing and this spec is organized around it:

- **A claim about the state of the repo** — this path exists, this symbol is exported, this command is the real gate — decays the moment the repo moves, and a model reading stale prose restates it with full confidence. Such claims must be **resolved mechanically at the moment of use**, never trusted from a document.
- **A procedure for exercising judgment** — "would this criterion pass if the function threw on line 1" — does not decay, because it describes how to think rather than what is true. Prose is the right medium for it.

The corollary governs what is *not* in this spec. The originally proposed verdict-class taxonomy is largely a restatement of rules that already exist in `agents/dag-auditor.md:54-77` (positive claims need `file:line`; negative claims need two independent search strategies; "docs are not evidence about code"). Those rules were in force during every measured failure above. **A fourth restatement of an ignored rule is not a fix.** What was missing is a mechanism, so this spec ships one and reduces the taxonomy work to the two deltas that are not restatements.

The same reasoning bounds item A below. Wiring a prose charter into four more roles multiplies the blast radius of stale prose — one consumer repo's charter carried an **inverted** fact about a test fixture for months, and a lens reading it would have confidently cleared a vacuous test. So the charter ships with a **freshness mechanism**, not with an instruction to be careful.

## Classification principle (governs this batch and future work)

| Kind of claim | Medium | Enforced by |
|---|---|---|
| Fact about the repo | resolved at use | shipped executable |
| Judgment procedure | prose | model, at authoring or audit time |
| Schema validity | prose rule + refusal | validator, no silent fallback |

A rule that asserts a repo fact in prose is a defect in this plugin, not a feature.

## Non-goals — must NOT land in the plugin

- Any concrete verification command, build tool invocation, or named test runner.
- Any named consumer-repo fixture, component, module, port, or proxy config.
- Any consumer repo's frozen decisions, enforcement map, or reference implementations.
- A `reference:` per-task pointer field. **Explicitly rejected** — see Decisions.
- Per-task `spec_reviewer:` / `quality_reviewer:` subagent-type fields. **Deferred** — see Decisions.
- An automated fixture runner. Out of scope, unchanged from prior releases.

## Architecture

Two seams and one shared resolver.

```
                    .claude/audit-charter.md
                       (one file, role-sectioned)
                              |
        +---------------------+---------------------+
        |                                           |
   audit side                                 execution side
        |                                           |
  auditing-artifacts                        executing-dag-plans
   step 2 charter                            pre-flight charter
   step 2.6 PRE-PASS  <--- resolve-declared-paths --->  (same helper)
        |                                           |
   N lens dispatches                     implementer + 3 reviewer
   (table in stable prefix)               dispatches (section 2)
        |
   reconciler
```

`resolve-declared-paths` is the only new executable. It serves both seams and runs **once per audit, before fan-out** — the token and tool-call saving is the point, not a side effect (see B5).

---

## A. Charter role map and verification commands

**File:** `skills/auditing-artifacts/audit-charter-template.md`

### A1. Role to section map

Add a table near the top declaring which role reads which section, so a charter author knows the audience and so the dispatch templates have one source of truth to reference:

| Section | auditor | implementer | reviewers |
|---|:---:|:---:|:---:|
| Enforcement map | yes | | yes |
| Hard invariants | yes | yes | yes |
| Named reference implementations | yes | yes | |
| Recurring bug classes | yes | yes | yes |
| Frozen decisions | yes | | |
| Verification gotchas | yes | yes | |
| Verification commands (new) | yes | yes | yes |

**"reviewers" means all three review roles** — `dag-spec-reviewer`, `dag-quality-reviewer`, and `dag-merged-reviewer`. The merged reviewer performs both halves in one pass, so it takes the same set rather than a union of two different ones.

### A2. New `## Verification commands` section

The existing `## Verification gotchas` lists commands that report success while having failed. It does not cover the case where nothing lies and the correct command is merely non-obvious — which is what an implementer needs most.

Add a positive-form section. To stop the two drifting: **gotchas holds the trap; the replacement command belongs in the new table.** One line in the template states that boundary.

`## Verification gotchas` is **not renamed or restructured** — consumer repos have already copied it, and the role map addresses sections by name.

### A3. Acceptance

- The template declares a role-to-section map covering every section it defines.
- The new section exists with generic placeholder rows only.
- No section is renamed; a pre-existing charter remains valid unchanged.

---

## B. `resolve-declared-paths` — the shared resolver

**New file:** `skills/auditing-artifacts/resolve-declared-paths`
POSIX `sh`, extensionless, executable, LF-pinned via a new `.gitattributes` entry — mirroring `skills/executing-dag-plans/git-commit-safe`.

### B1. Interface

```
resolve-declared-paths <artifact-path> <repo-root> [charter-path ...]
```

Exit `0` on a completed run **regardless of what it finds**; `2` on usage error; `1` when the artifact cannot be read. Findings are data, not failure.

### B2. Table 1 — declared paths

Extraction:

- Every entry under a `files:` key in a task YAML block.
- Path-shaped backticked tokens in prose: contains `/` **and** a dot-extension.
- **Skipped entirely**: tokens containing `*`, `?`, or `://`. A glob reported ABSENT would manufacture the false-absence finding this exists to kill.

Status vocabulary: `EXISTS` · `ABSENT` · `DIR`.

The `declared at` column distinguishes `task-N files:` from `prose L<n>`, because the two read completely differently and the interpretation rule depends on it.

### B3. Table 2 — charter citations

The charter template already mandates that every entry cite `file:line`. That makes the charter mechanically checkable, which is the whole basis of this table.

For each citation: resolve the file, resolve the line into range, then match an **anchor** against the cited line plus or minus 2 lines.

The anchor is the set of alphanumeric tokens of length 4 or more drawn from the entry's own label. The charter uses two entry shapes and both must be handled:

- **bullet sections** (hard invariants, recurring bug classes) — the label is the leading bolded name;
- **table sections** (enforcement map, reference implementations, verification commands) — the label is the row's first cell.

An entry matching neither shape yields no anchor, and therefore `OK-UNANCHORED`.

Status vocabulary:

| Status | Meaning |
|---|---|
| `OK` | file and line resolve; an anchor token matched |
| `OK-UNANCHORED` | file and line resolve; the entry had no extractable anchor |
| `SUSPECT` | file and line resolve; no anchor token matched in the window |
| `MOVED` | file exists; cited line out of range |
| `GONE` | file does not exist |

**`OK-UNANCHORED` exists to prevent manufactured suspicion.** An entry with no extractable anchor is never reported `SUSPECT` — absence of an anchor is a property of the entry's phrasing, not evidence of drift.

**Known limitation, stated rather than papered over:** an entry whose fact inverted while its cited line stayed valid and still contains its anchor is **not** caught. Anchor matching narrows that window; it does not close it.

### B4. Consumption

**Audit side** (both tables):

- `auditing-artifacts/SKILL.md` gains **step 2.6**, between downstream artifacts (2.5) and the prior-audit check (3) — i.e. **before the lens fan-out at step 5**.
- `auditor-prompt.md` gains a block at **section 3.5**, before the lens fragment. The table is byte-identical across all N dispatches and therefore belongs in the cache-stable prefix, per the template's existing ordering comment.
- Two interpretation lines travel with the table:
  - an `ABSENT` path in a create-task's `files:` is **expected**, not a finding;
  - a path cited **in prose as already existing** that is `ABSENT` is the hallucination case.
- **One hard guarantee, one direction:** a lens may not contradict an `EXISTS`. That is the entire measured defect class and it needs no judgment to enforce.
- If the helper cannot run, the skill states *"path pre-pass did not run"* to every lens rather than omitting the block — the same "none found is not the same as omitted" rule already applied to downstream artifacts at `auditor-prompt.md:16-19`.

**Execution side** (charter-citation table only):

- The `executing-dag-plans` pre-flight runs the helper **once, before the first tick**, passing only the charter paths it just resolved. The declared-paths table is not produced here: an executor's plan describes files that do not exist yet by design, so that table carries no signal on this side.
- The resulting citation statuses ride into the four dispatch templates alongside the charter text (see C2), so a `SUSPECT`, `MOVED`, or `GONE` entry arrives flagged rather than as bare prose.
- Same failure rule: if the helper cannot run, the templates say so explicitly rather than presenting unflagged charter text as verified.

### B5. Why before fan-out

Today each of 7 lenses independently globs, greps and stats the same handful of paths — roughly 20-40 redundant tool calls per audit, and 7 private inferences where one shared resolution would do. One run replaces all of them, and the stable-prefix placement keeps it from costing N times the tokens.

### B6. Acceptance

- Running the helper against a plan emits both tables and exits `0`.
- A glob entry in a task's `files:` appears in neither table.
- A charter entry with no extractable anchor reports `OK-UNANCHORED`, never `SUSPECT`.
- The audit skill dispatches lenses with the table present, or with the explicit did-not-run notice.

---

## C. Execution-side charter wiring

**Files:** `skills/executing-dag-plans/SKILL.md`, `implementer-prompt.md`, `spec-reviewer-prompt.md`, `quality-reviewer-prompt.md`, `merged-reviewer-prompt.md`

### C1. Latent bug being fixed

All three reviewer templates declare `(2) project conventions (if any)` in their section-order comments — `spec-reviewer-prompt.md:23`, `quality-reviewer-prompt.md:24`, `merged-reviewer-prompt.md:13` — and **none of the three templates contains such a section.** The seam was designed and never wired. Only `implementer-prompt.md:34-36` delivers it.

### C2. Changes

- `SKILL.md`: charter location **and the B4 execution-side helper run** are added to the **existing pre-flight paragraph** (the one already checking the agent registry and `*_hint` values). Both happen once, before the first tick — not per dispatch. Strictly additive; no restructuring of the tick loop.
- `implementer-prompt.md`: `## Project conventions` widens from `{contents of repo's CLAUDE.md, if any}` to CLAUDE.md **plus the implementer's charter sections**, plus the citation-status table from B3 so a `SUSPECT` entry arrives flagged.
- The three reviewer templates **gain the section they already promise**, each with its role's sections per A1.

### C3. Rules

- **Verbatim sections, never a summary.** `auditing-artifacts` step 2 already states "do not summarize it for them"; inlining verbatim honours that while keeping content in the cache-stable prefix.
- **"(none found)" is written explicitly**, never omitted.
- **A charter section is context for the remit a role already owns, not a new remit.** The quality reviewer is told "Do NOT flag missing/extra requirements"; charter content must not quietly reopen that boundary.

### C4. Acceptance

- All four templates contain a populated section 2 consistent with A1.
- Absent charter yields an explicit "(none found)", not an omitted section.
- No template gains a remit its output contract does not already grant.

---

## D. Reconciler deltas

**File:** `agents/dag-audit-reconciler.md`

Two changes only. The severity taxonomy already exists and is not restated.

- **D1** (`:97`, and the READY rule at `:170`): `EMPIRICAL-UNKNOWN` resolves to **an acceptance criterion on the owning task**, with a probe task only where no task owns the surface. Today's unconditional probe task adds a DAG node for something an existing task can carry.
- **D2** (downgrade-rules block): a **world-claim** — a claim about repo state — that contradicts the pre-pass table, or that carries neither command output nor citation, downgrades to `UNVERIFIABLE` **with the reason logged**. No new machinery: the downgrade log exists and is already surfaced to the author.

**Acceptance:** an unevidenced world-claim reaches the verdict as `UNVERIFIABLE` with a log line, not as its proposed severity, and is never silently dropped.

---

## E. Gate-2 `ambiguity` lens

**File:** `skills/auditing-artifacts/lenses-plan.md`, roster 7 to 8.

Gate 1 has an `ambiguity` lens; gate 2 does not. Plan-side `coverage` and `verifiability` both **pass a faithfully transcribed ambiguous requirement** — the plan is a faithful rendering of an unfalsifiable ask.

This lens is **not a copy of gate 1's.** Lenses are told the parent spec is "APPROVED AND FROZEN — do not reopen its design decisions." Scope:

- ambiguity the plan **introduced** in transcription;
- ambiguity the plan **inherited and failed to resolve** — the plan's job is to make a requirement executable, so transcribing an unfalsifiable ask faithfully is a *plan* defect even though the spec is its source;
- requirements that **cannot be false**, so no test can fail.

Explicitly out of scope: relitigating a spec decision that is clear but that the lens would have decided differently. Gate 1 asks *"is this ambiguous?"*; gate 2 asks *"did the plan resolve what it inherited, and did it add any?"* Without that boundary the lens generates the churn the frozen-spec rule exists to prevent.

**Acceptance:** the lens flags an unfalsifiable requirement introduced at plan time, and returns no finding on a clear frozen spec decision it merely dislikes.

---

## F. Schema additions

**File:** `skills/writing-dag-plans/plan-format.md`

### F1. `spec:` (plan-level, optional)

A **single file** path to the design the plan implements; a superspec charter where the design spans files, never a directory — a directory cannot be diffed against a claim.

- Validated at authoring (`writing-dag-plans` step 6) **and** in the executor pre-flight, reusing that paragraph's stated rationale: it "catches hand-edits that bypassed the writing-dag-plans validator." A `spec:` resolving to nothing **refuses** — worse than absent.
- Consumed by `resolve-declared-paths` and by gate 2 as the parent-spec path.
- **`writing-dag-plans` emits it automatically**, since it already knows the spec it was invoked from. New plans get it free; existing plans keep working.

Provenance is unstructured prose today (`plan-format.md:15` asks only for a `## Context` section). Nothing can resolve it, diff against it, or notice supersession — yet that comparison is gate 2's whole job, and a `coherence-superseded-no-marker` fixture already exists.

### F2. `default_implementer:` (plan-level, optional)

Completes the chain `task.implementer` then `default_implementer` then `dag-implementer`.

The executor's registry pre-flight currently validates "every distinct `implementer:` value" and **must include the plan-level default**, or a typo there escapes pre-flight and fails at dispatch — violating the no-silent-fallback rule the `*_hint` fields already hold.

**Acceptance:** both fields validate identically to existing plan-level keys; a typo or unresolvable path halts pre-flight naming the field and value; omitting both leaves behaviour byte-identical to v0.5.0.

---

## G. S16 — rendered output needs a verification owner

**File:** `skills/writing-dag-plans/plan-quality.md`, soft heuristic.

> **S16 — Rendered-output change with no verification owner.** Trigger: some task's `files:` contains a rendered-surface file — by extension `.tsx`, `.jsx`, `.vue`, `.svelte`, `.component.html`, `.html`, and style files only when accompanied by one of those — AND no task's acceptance criteria name a rendered-surface check. **Suppressor:** a task already owns it. **Fix:** add a task owning visual verification, naming the surface, the entry point, and the actor.

Generic form of a recorded lesson: *a gate no task owns is a gate nobody runs.* Per-task gates structurally cannot cover a cross-task rendered result, and the defect class it targets — inferred columns, an empty async dropdown, an orphaned overlay, an invisible toast — is invisible to unit tests, spec review and quality review alike.

Detection names **file extensions only** — no framework, component library, port, or dev-server command. Fires **once per plan**: a missing owner is a plan-level gap, and the S12-S15 reasoning is that the unit of the defect sets the unit of the warning.

**Acceptance:** a plan changing rendered surfaces with no owning task warns; the same plan with an owning task does not.

---

## H. Red-to-green evidence at review

**Files:** `implementer-prompt.md`, `quality-reviewer-prompt.md`, `merged-reviewer-prompt.md`

`dag-implementer` already carries `skills: [test-driven-development]`, so it already observed the failing test. It was never asked to report it.

- **Implementer:** the DONE output block gains a required field for test-bearing tasks — the assertion that failed and its message, observed **before** the fix.
- **Quality and merged reviewers:** an approval criterion — the evidence must be present and coherent with the diff (the named assertion exists in it and could plausibly have failed as reported). Absent or incoherent is `ISSUES`.
- **Narrow escalation:** where a task's stated value *is* the guard — a regression test, a security assertion — the reviewer runs the mutation itself.

Chosen over reviewer-run mutation as the default because the evidence is captured where it is free, and verifying it costs a read rather than an execution across every test-bearing task in a plan.

**Acceptance:** a task whose test passes with the implementation reverted is caught at review, without the reviewer running a mutation on every task.

---

## Decisions

- **DECIDED:** one charter file (`.claude/audit-charter.md`) with a role-to-section map — not a second `execution-charter.md`. Three of the sections an execution charter would need already live in the audit charter; two files would duplicate them, and the template's own warning is that a charter duplicating another doc "is worse than absent." — 2026-08-27
- **DECIDED:** `reference:` per-task pointer field is **rejected**. H11 already refuses a bare spec pointer in acceptance criteria, and the `context-sufficiency` lens already owns pointer-instead-of-inline as BLOCKING with a fixture. The field's own proposal pairs it with a guard that exists only to contain the hazard the field introduces. — 2026-08-27
- **DECIDED:** per-task `spec_reviewer:` / `quality_reviewer:` subagent-type fields are **deferred**, not rejected. `plan-format.md:104`'s persona-agnostic reviewers are a principle, not an accident: routing implementation and review of one task to the same persona costs the adversarial distance the split chain creates. The only stated motivation was grid symmetry. Revisit on a concrete case. — 2026-08-27
- **DECIDED:** the verdict-class taxonomy is reduced to D1 and D2. The rest restates `dag-auditor.md:54-77`, which was in force during every measured failure. — 2026-08-27

## Empirical unknowns

- **Anchor-match false-positive rate on real charters.** `SUSPECT` is a judgment aid, not a gate, so a false positive costs attention rather than a blocked audit. Settled by running B against two real charters and counting.
- **Whether S16's extension list under-fires on template-driven stacks** where rendered output lives in files with non-listed extensions. Same under-firing asymmetry documented for S12: a missing token produces no output. Settled by running it against real plans.

## Rollout and acceptance gate

Order follows dependency, not importance:

1. **A** (charter template) and **B** (helper) — independent of each other, both root.
2. **C** (execution wiring) consumes both: A defines the section names it extracts, B supplies the citation statuses it attaches. **D** (reconciler) consumes B's table.
3. **E, F, G, H** — independent of each other and of everything above.
4. Version bump to `0.6.0`, `.gitattributes` entry, README additive sections. Last, since it must reflect what actually landed.

**Gate:** every new fixture is dispatched at its lens or rule **once** and its header reconciled before commit. `tests/fixtures/audit/README.md` makes this a hard rule because six of eleven fixtures carried undeclared defects on their first run. This is the largest single cost in the release and it is not compressible.

Fixture homes — existing directories, no new top-level buckets:

| Change | Home |
|---|---|
| D2 downgrade | `tests/fixtures/audit/reconciler/` |
| E lens | `tests/fixtures/audit/should-flag/` + coverage-table row |
| G | `tests/fixtures/visual-verification/` (should-warn, should-pass) |
| F | `tests/fixtures/schema/should-refuse/` |

**Non-goals check, applied at review:** no construct from a single consumer repo appears anywhere in the diff.

## Open questions

None blocking. Both empirical unknowns above are settled by running the artifact after it exists, and neither gates authoring.
