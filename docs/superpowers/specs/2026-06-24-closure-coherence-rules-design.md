# Closure-Coherence Rules for DAG Plan Authoring — Design Spec

**Date:** 2026-06-24
**Skills targeted:** `parallel-dag-execution:writing-dag-plans`, `parallel-dag-execution:updating-dag-plans`. Plus new conformance fixtures.

**Dependency:** Builds on the existing contract-sequencing work (H8 import resolution, H9 consumer→definer sequencing, step 6.5 contract-surface identification). This spec references those artifacts as existing and extends the index H9 already builds.

## Goal

Close the **coherence-between-tasks** gap that file-disjointness and H9 structurally cannot see: a capability consumed by one task and produced by **none** (the "marquee feature with no data path" hole), and an interface that crosses a subsystem cut where each branch invents its own incompatible half (response-envelope drift). Plus kill the highest-frequency authoring slip: acceptance criteria that point at a spec section instead of inlining the requirement, and elided "the other three follow the same shape" implementation blocks that pass review on hollow stubs.

## Why

File-disjointness (`files:` validation rule #4) is a **write-conflict guard** — it prevents two parallel implementers clobbering each other. It is not a contract-coherence guard. The plugin already has a partial coherence guard in **H9**, but H9 is *presence-gated and producer-existence-gated*: it only fires on `(consumer, symbol, definer)` triples where the definer **exists** as another task. Two failure shapes escape it entirely:

1. **Missing producer.** A component consumes `state.myTasks()`; no state method, API client method, controller endpoint, or repository query produces that capability. H9 builds its definer index, `myTasks` is not in it, so no triple forms — and H9 only refuses on triples. The marquee feature's data path is absent, yet every `files:` dependency is satisfied and the plan validates clean.
2. **Unanchored contract.** The API client pins `listTaskLists → { items, nextCursor }`; no schema defines that envelope and the service returns a bare array. Both sides invent half an interface; `.items` is `undefined` at runtime; it compiles on both sides.

Separately, two **intra-task** authoring slips are high-frequency and currently uncaught:

3. **Bare spec pointers.** An acceptance criterion of the form "match spec §5.1 exactly" is verifiable by the reviewer subagent *only if it reloads the spec* — which the executor's reviewers never see (the task body IS the binding spec). H4 (criteria present) and S4 (single-word criteria) both pass it. Partial expansion sails through.
4. **Elided siblings.** "`task-schema-tables` fully writes `task_lists` and the other three follow the same shape per §5.1." The existence of a thin sibling file passes any "does it exist" check while the spec wanted the full shape.

## Why fold into existing rules, not add a standalone gate

A standalone "closure gate" (the originally-proposed shape) re-derives a consume/produce ledger and re-checks **missing-edge** — which is exactly what H9 already refuses on. Two mechanisms for one defect are free to diverge in wording and severity. Folding the *novel* checks into the index H9 already builds gives one definer/consumer index, one refusal format, and automatic inheritance by `updating-dag-plans` (which enforces `plan-quality.md` through its per-op matrix). H9 keeps missing-edge; the new rules cover only what H9 cannot see.

## Classification principle (governs this batch and future rules)

- **Binary-checkable truth → hard rule (refuse).** "The capability is absent or it isn't" — missing-producer. "A bare pointer is present or it isn't" — bare-spec-pointer.
- **Judgment ("is this worth it here") → soft heuristic (warn).** "A shared schema is sometimes overkill" — unanchored-contract.

This is why H10/H11 refuse and S11 warns.

## Non-goals

- **v2 deterministic ledger.** `provides:`/`consumes:` task frontmatter plus a `validate-closure` script that machine-checks closure (and surfaces producer edges into the mermaid graph). Deferred — evidence-gated. Build only if the LLM/index gate's misses cluster; the fixtures below are the eval set for that decision.
- **A persisted ledger artifact** in the plan file. Rejected: it is a third source of truth that drifts from the code blocks and fights the "regenerate from scratch, never hand-edit" rule. If persistence is ever wanted, go straight to v2 frontmatter.
- **An automated fixture runner.** Out of scope; fixture verdicts remain LLM-executed, the same fidelity as every existing rule test. Recorded as a known limitation, not a gate.
- **Re-checking missing-edge.** H9 owns it. The new rules must not duplicate it.
- **Changing file-disjointness or any existing H/S rule's behavior.** All changes are additive.

## Architecture

All changes are additive. A plan that closes cleanly today validates identically.

| File | Change |
|---|---|
| `skills/writing-dag-plans/plan-quality.md` | Add hard rules **H10** (missing-producer) and **H11** (bare-spec-pointer); add soft heuristic **S11** (unanchored-contract). Update §Detection algorithm to run H10/H11/S11. Add refusal/warning examples. Fix the stale `step 11.5` → `step 8` cross-reference (line ~79). |
| `skills/writing-dag-plans/SKILL.md` | Step 8 decomposition audit gains: the **prose-consumption sweep**, the **elided-sibling enumeration**, and a **reworded quality lens** (repo convention docs + per-layer reference impl, replacing the generic "industry-standard" phrasing). Update step 7's hard-rule range (H1–H9 → H1–H11) and soft range (S1–S10 → S1–S11), the §Required reading H/S ranges, and the process digraph. |
| `skills/updating-dag-plans/SKILL.md` | Step-6 per-op matrix: add H10/H11 to **add task** and **modify body**; add S11 to **rewire `depends_on:`** and **add task**. Extend the §Hard rules `:111` note: when adding a task that consumes a capability, a **`done` task counts as a valid producer** (H10 is satisfied by any producer in the plan, immutable or not). Update §Required reading H/S ranges. |
| `tests/fixtures/contracts/should-refuse/h10-missing-producer.md` | NEW. The myTasks hole. |
| `tests/fixtures/contracts/should-refuse/h11-bare-spec-pointer.md` | NEW. Acceptance criterion whose only content is `per spec §X`. |
| `tests/fixtures/contracts/should-warn/s11-unanchored-contract.md` | NEW. Composite `{items, nextCursor}` envelope crossing a cut with no shared schema. |
| `tests/fixtures/contracts/should-pass/*.md` | NEW additions: cross-cut-via-shared-named-schema (S11 silent), checksum'd criteria (H11 pass), renamed-but-wired capability. |

**What stays the same:** H1–H9, S1–S10, structural validation rules #1–#10, file-scope tripwire, the parallel-dispatch contract, S8 contract co-location, step 6.5, mermaid/ASCII formats, the tier and review-mode systems.

## Rule specifications

### H10 — missing-producer (hard)

**Unique scope (tighter than "any unresolved reference"):** the import-level missing case is already caught by **H8** (imports resolving to nothing); the missing-edge case by **H9**. H10 owns only the **member/method gap**:

> A task imports `state` from task-X (H8 passes — the file resolves; H9 passes — `myTasks` is not in the definer index, so no triple forms). The task then references `state.myTasks()`. H10 fires: the accessed member `myTasks`, on an object owned by task-X, is defined by no producer.

**Index extension required:** H9's extractor indexes top-level `export`s. H10 additionally indexes **members/methods/fields within exported classes/objects** so it knows `state.myTasks` requires a `myTasks` member on whatever task produces `state`. This extension is the primary implementation work and the main false-positive surface.

**Detection.** For each task, collect member/property/method accesses (and named imports) whose base symbol or import path is **owned by another task T** (per H8's file-classification). For each such accessed member `m`: if `m` is not in T's defined-symbol set (top-level exports ∪ indexed members) → **MISSING PRODUCER** → refuse.

**Skips (inherited from H9/H8):** symbols/members resolving to a **pre-existing file** or an **external dependency** are not missing producers — this covers externally/dynamically-produced capabilities. Same-task references are skipped.

**By-design firings (not false positives):** a naming mismatch (`myTasks` consumed, `tasksForUser` produced) fires — the named capability genuinely is not wired. The author resolves by reconciling the name or adding the producer.

**Partition with the prose sweep:** H10 owns references appearing in **code blocks**. The prose-consumption sweep (step 8) owns references appearing **only in prose / acceptance text**. A reference in both resolves to the H10 finding only — never two competing findings.

**Refusal text (substring-matchable, mirrors H9):**
```
task-<id> violates H10 (consumed capability has no producer)
  Capability: <base>.<member>  (e.g. state.myTasks)
  Owner:      task-<owner> (produces <base>, file: <path>)
  Issue:      task-<id> references <base>.<member> but task-<owner> defines no <member>
  Fix:        add a producer for <member> (state method + its api-client/controller/repository
              data path) OR correct the reference if <member> was renamed
```

### H11 — bare-spec-pointer (hard)

Generalizes the rule the skill already applies at the charter boundary ("inline the actual requirement … never a bare pointer") to **all** acceptance criteria within a single plan.

**Detection (binary trigger):** an acceptance-criteria bullet whose substantive content is **only** a spec reference — matches a section-pointer pattern (`§`, `per spec`, `see §`, `match spec section`, `as in section`, `follows §`) AND, with the reference removed, carries no concrete requirement text and no countable checksum (a number/quantity the reviewer can verify, e.g. "11 schema files", "13 event names"). A bullet that inlines the requirement *and also* cites the section as provenance passes (provenance is encouraged, not refused).

**Fix:** inline the requirement fragment, or add a countable checksum. (Whether a checksum is a *good* one is judgment — not gated.)

**Coupling to elided-sibling (step 8):** the elided-sibling enumeration requires each implied sibling to itself satisfy H11, so "the sibling exists" cannot pass on a hollow stub.

**Refusal text:**
```
task-<id> violates H11 (bare spec pointer in acceptance criteria)
  Bullet: "<the offending bullet>"
  Issue:  criterion defers to a spec section the reviewer never sees; no inlined
          requirement and no countable checksum
  Fix:    inline the requirement fragment, or add a countable checksum
          (e.g. "re-exports all 11 schema files"); citing §X as provenance is fine
          once the requirement itself is present
```

### S11 — unanchored-contract (soft)

**Detection:** an interface that crosses a subsystem cut (two tasks whose `files:` span distinct top-level subsystem prefixes, e.g. `apps/api/**` and `apps/modules/**`, or `src/api/**` and `src/ui/**`) where one side asserts a **response/payload shape** and no single contract artifact (a shared schema both sides `depends_on`) defines it.

**Suppressor (keeps the warning high-signal):** fires only on a **composite, unnamed** shape — an object/envelope with ≥2 fields, e.g. `{ items, nextCursor }`. Exempt when the crossing value is a **primitive** (`number`, `string`, `boolean`) or a **shape already named in a shared type** both sides reference. This prevents the warning from becoming dismissible-by-default.

**Warning text:**
```
S11 — task-<consumer> / task-<producer> unanchored cross-cut contract
  Shape:   { items, nextCursor } crossing <api-subsystem> ⇄ <ui-subsystem>
  Concern: consumer asserts this envelope; no shared schema defines it; producer
           free to return an incompatible shape (compiles on both sides)
  Suggestion: add a shared contract schema as its own task; make both sides depends_on it
```

## Semantic checks (SKILL.md step 8 audit)

Added to the existing LLM-judgment decomposition audit (mirrored into `updating-dag-plans` where the op touches task bodies/edges):

- **Prose-consumption sweep.** For capabilities referenced only in prose / acceptance criteria (never in a code block), name the producing task; flag any with no producer. Complements H10 by the code/prose partition.
- **Elided-sibling enumeration.** Detect elision phrases ("the other N", "follow the same shape/pattern", trailing "etc.", "per §X" standing in for content). Enumerate the implied siblings and require each to exist **and** satisfy H11. Coupled to H11 so existence can't pass on a hollow stub.
- **Reworded quality lens.** Replace the generic "industry-standard hygiene" phrasing with: check adherence to the repo's own convention docs and the **per-layer** named reference implementation (e.g. "mirror `haul/events.ts`", "shape of `integrations/` not `miller-paving/`"), not a blanket "see haul" or a generic industry prior.

## Rollout & acceptance gate

- **H10 ships hard, gated on a clean run:** zero H10 findings across **all existing `should-pass` fixtures** (contracts, tiers, review-mode — the in-tree known-good corpus) plus the new `should-pass` additions. A false positive that index-tightening cannot resolve degrades **that case** to a soft warning; the rule does not ship hard if it cannot run clean on known-good.
- **H11 and S11** validated by their dedicated fixtures plus a no-regression pass on existing `should-pass` fixtures.
- **Known limitation (recorded):** no automated runner — verdicts are LLM-executed. Not a CI gate; same fidelity as all existing rule tests.

## Open questions

None outstanding. Two calls confirmed during design: (5) elided-sibling lives in the step-8 LLM audit (needs judgment to infer implied siblings) rather than as a mechanical rule; H11 is hard (per binary→hard), accepting it may nag on legitimately terse criteria.
