# DAG Plan Contract-First Rules — Design Spec

**Date:** 2026-05-04
**Skill targeted:** `parallel-dag-execution:writing-dag-plans` (DAG-first), with the spec written to allow a later port to `superpowers:writing-plans`.

## Goal

Add two new rules to the DAG plan validator so that contracts (types and exported function/method signatures) are sequenced correctly across parallel tasks and surfaced as first-class artifacts rather than buried inside business-logic files.

- **H9 (hard, refuse):** if a task imports or references a contract symbol defined by another task in the plan, the consumer must transitively `depends_on:` the definer.
- **S8 (soft, warn):** contract symbols should live in a dedicated convention dir (`contracts/`, `types/`, `models/`, `schemas/`, `proto/`, `openapi/`, etc.). If the repo has no such dir, fall back to a mixed-concerns smell — warn when contract definitions sit in the same file as non-contract code.

## Why

Today, two parallel implementer subagents can each invent their own shape for a shared type because nothing in the plan forces a definer-before-consumer ordering. The structural validator (`plan-format.md`) and existing quality rules (H1-H8, S1-S7) catch many decomposition smells but treat contracts as ordinary code. Concretely:

- **H8 (import resolution)** ensures imports point to a file someone owns, but says nothing about *temporal* ordering. A consumer task whose `depends_on:` is empty can still pass H8 by importing from a file owned by a sibling task.
- **H7 (`## Implementation` shape)** requires fenced impl + failing-test code blocks but doesn't distinguish "this code defines a contract everyone else uses" from "this code is internal".

The result: when continuous parallel dispatch is the whole point of this plugin, the planner must own contract sequencing — the executor is too late.

The co-location heuristic exists separately because even with sequencing right, a `Claim` type buried inside `src/processor.ts` is harder to find, harder to reuse, and produces silent drift between two consumers who pull from different inlined definitions. Pushing contracts to a recognizable location is the standard industry hygiene fix.

## Non-goals

- **Runtime contracts** (DB schema, message/event payloads, env vars, CLI flag specs). Real, but out of scope for this spec — they can ride a future S-rule. This spec covers types + exported function/method signatures only.
- **Touching `plan-format.md`.** This is a quality concern, not a structural one. The `## Implementation` block schema already supports everything we need.
- **Touching `executing-dag-plans/`, `dag-implementer/`, or any agent definitions.** New rules live entirely in the planner; the executor and implementer subagents see them indirectly via plans that pass validation.
- **Auto-fixing violations.** Rules refuse or warn with a suggested fix; the user revises the plan and re-runs validation. No auto-mutation.
- **Building an automated eval harness.** Hand-validated fixtures + manual checklist (see Testing).

## Architecture

All changes are localized:

| File | Change |
|---|---|
| `skills/writing-dag-plans/plan-quality.md` | Add H9 to hard rules table, S8 to soft heuristics table, bump detection-algorithm rule numbering, add a "Contract clarity" bullet to the decomposition-principles audit list. |
| `skills/writing-dag-plans/SKILL.md` | Insert step 6.5 (planner-side contract surface walk), update steps 7 and 8 to reference H1-H9 and S1-S8, add one bullet to step 9, add one anti-pattern entry. |
| `skills/updating-dag-plans/SKILL.md` | (1) Add a `## Hard rules` bullet enforcing H9 against new tasks that consume contracts from `done` tasks. (2) Update step 6 (Re-run quality validation) to add H9 to the rule list under **add task** and **modify body** operations. (3) Update `## Required reading` to reference H1-H9 and S1-S8 (also fixes a pre-existing staleness — the file currently lists H1-H6 / S1-S6). |
| `tests/fixtures/contracts/should-pass/*.md` | New fixtures (6 plans). |
| `tests/fixtures/contracts/should-refuse/*.md` | New fixtures (2 plans). |
| `tests/fixtures/contracts/should-warn/*.md` | New fixtures (2 plans). |
| `docs/superpowers/specs/2026-05-04-dag-plan-contract-rules-design.md` | This spec (already written). |

No new top-level reference doc — H9 and S8 join the existing taxonomy in `plan-quality.md`. No changes to `plan-format.md`.

## Detection mechanics (shared between H9 and S8)

Both rules consume the output of two new passes that extend the existing import-extraction infrastructure used by H8 and S7:

### Pass 1 — Definer index

For each task, parse fenced code blocks under `## Implementation`. Extract every defined contract symbol matching these per-language patterns:

| Language / format | Patterns extracted |
|---|---|
| TypeScript / JavaScript | `export (interface\|type\|class\|function\|const) <Name>`, `export default (function\|class) <Name>` |
| Python | `^class <Name>` (top-level), `^def <Name>(`, `^<Name>: TypeAlias`, `@dataclass\nclass <Name>`, `class <Name>(Protocol)`, `class <Name>(TypedDict)` |
| Rust | `pub (struct\|enum\|trait\|fn\|type) <Name>` |
| Go | `^(type\|func) <Name>` (capitalized name → exported) |
| JSON Schema | top-level keys under `definitions:` or `$defs:` |
| OpenAPI | top-level keys under `components.schemas:` |
| Protobuf | `message <Name>`, `enum <Name>`, `service <Name>` |
| GraphQL | `type <Name>`, `interface <Name>`, `enum <Name>`, `input <Name>` |

Build a map `(file_path, symbol_name) → defining_task_id`. Same-name symbols in different files are distinct entries.

### Pass 2 — Consumer index

For each task, parse fenced code blocks for *references* to symbols in the definer index. Two reference forms:

1. **Imports** — primary signal. Same regex extraction as H8 (`import { Foo } from '<path>'`, `from <module> import Foo`, `use <crate>::Foo`, `import "<file>"`).
2. **Direct usage** — secondary signal. After import resolution, scan code blocks for token references to definer-index symbol names that are NOT defined in the consumer's own code blocks. Catches type usage in function signatures (`function bar(c: Claim)`), generic params, type assertions, etc.

Build a list `(consumer_task_id, defined_symbol_name, definer_task_id)`.

### Edge cases shared by both passes

- **Pre-existing files** — if an imported file path matches a file already in the codebase (filesystem read), the symbol is a pre-existing dep, NOT a plan dep. Skip both H9 sequencing and S8 co-location for these. Reuses H8's pre-existing classification.
- **External package imports** — package paths that resolve to `node_modules`, `Cargo.toml` deps, `pyproject.toml` deps, etc. Never plan-internal contracts; never violations.
- **Same-task references** — a task referencing its own definitions never violates either rule.
- **Test files** (file paths under `tests/` or `test/`) — exempt from S8 Branch B's mixed-concerns check (test fixtures are not shared contracts), but still subject to H9 if they import a plan-defined contract.
- **Schema-as-code files** (`.proto`, `.openapi.yaml`, `.openapi.yml`, `.graphql`) — file extension itself signals contract-only intent. Exempt from S8 Branch B.
- **Wiring tasks** (`is_wiring_task: true`) — H9 applies normally (they `depends_on:` their parents already by convention). S8 exempts them — wiring tasks legitimately compose contracts from multiple sources.

## H9 — Contract-sequencing (hard rule)

### Rule

> If task B's `## Implementation` block imports or references a contract symbol defined by task A elsewhere in the plan, then there must be a transitive `depends_on:` path from B to A. Otherwise refuse.

### Detection

Run after Pass 1 and Pass 2 produce the definer/consumer indices. For each `(consumer_task_id, defined_symbol_name, definer_task_id)` triple where `consumer_task_id ≠ definer_task_id`:

1. Compute the transitive `depends_on:` closure of `consumer_task_id` (DFS over `depends_on:` edges already used by structural validation for cycle detection).
2. If `definer_task_id ∉ closure` → **violation**.

### Refusal output

Match the existing H-rule refusal style. Example:

```
✗ Plan refused — quality issues:

  task-claims-processor violates H9 (missing contract dependency)
    Symbol: ClaimRecord
    Defined by: task-claims-contracts (file: src/contracts/claim.ts)
    Issue: task-claims-processor references ClaimRecord but does not depends_on task-claims-contracts (transitively)
    Fix:   add "task-claims-contracts" to task-claims-processor.depends_on
```

When multiple symbols are missing, group by `(consumer_task, definer_task)` so the user sees one entry per missing edge.

### What H9 does not catch

- Runtime contracts (DB schemas, message payloads). Out of scope per Non-goals.
- Contracts where the consumer task does not yet reference the symbol in its `## Implementation` block but will at code-write time. The implementer subagent will add the import and either H8's import resolution (at re-validation) or runtime test failures will catch this. H9 only sees what the plan declares.

## S8 — Contract co-location (soft heuristic)

### Rule

> Contract symbols should live in a dedicated convention dir. If the repo has one, warn when symbols are defined outside it. If the repo has none, fall back to warning when contract symbols sit in the same file as non-contract code.

### Detection

Run once at validation start: **contracts-dir auto-detection**.

```
detected_dirs = []
for pattern in [
  "**/contracts/**", "**/types/**", "**/schemas/**", "**/models/**",
  "**/proto/**", "**/openapi/**",
  "src/types/**", "src/schemas/**", "src/contracts/**",
]:
  matches = glob(pattern)
  for match in matches:
    parent = parent_dir(match)
    if count_files(parent) >= 3:
      detected_dirs.append(parent)
detected_dirs = unique(detected_dirs)
```

Three-file threshold filters out empty placeholder dirs. Cache the result for the validation run.

For each task with defined contract symbols:

**Branch A — `detected_dirs` is non-empty:**

For each contract symbol the task defines, check if the symbol's file path starts with one of `detected_dirs`. If not → warning.

**Branch B — `detected_dirs` is empty:**

For each file in the task's `files:` list that contains contract symbols, check whether the same file *also* contains non-contract code in its `## Implementation` block. Non-contract code = anything that isn't an exported type/interface/dataclass/struct/trait/schema definition. Concretely: function bodies with side effects, top-level statements (`console.log`, `fetch`, `db.query`, runtime expressions outside type contexts), imports of side-effecting modules.

If both contract symbols AND non-contract code present → warning.

### Warning output

Match the existing S-rule warning style. Example (Branch A):

```
S8 — task-claims-processor contract co-location
  Symbol: ClaimRecord
  File:   src/claims/processor.ts
  Concern: project uses src/contracts/ for shared types, but ClaimRecord is defined here
  Suggestion: move ClaimRecord to src/contracts/claim.ts
```

Example (Branch B):

```
S8 — task-claims-processor contract co-location
  Symbol: ClaimRecord
  File:   src/claims/processor.ts
  Concern: ClaimRecord is defined alongside non-contract code (DB calls, side effects) in the same file
  Suggestion: extract types into a dedicated file (e.g., src/claims/types.ts or src/contracts/claim.ts)
```

Warnings are batched with other soft-heuristic warnings into the standard `save anyway? (y/N)` prompt (default N).

### What S8 does not do

- Does not refuse — heuristic only.
- Does not create dirs or move code — only references existing convention or proposes a path in the suggestion text.
- Does not warn on consumers (a consumer importing from a non-convention path is the definer's problem; flagged once at the source).

## SKILL.md flow changes

### `writing-dag-plans/SKILL.md`

**New step 6.5** between current step 6 (file-scope conflict detection) and step 7 (structural validation):

> **6.5. Identify contract surface.** Walk each task's `## Implementation` block and extract defined contract symbols (interfaces, types, exported function signatures, schema definitions). For each consumer task, identify which other tasks define symbols it imports or references. If any consumer task references a contract from a non-dependency, surface as a planner-level decision: either add the `depends_on:` edge or refactor to remove the cross-task reference. Loop until clean. (This is the planner-side mirror of H9 — catch the issue before it becomes a refusal at validation time.)

**Step 7 (structural validation) intro** stays unchanged — H9 is a quality rule, not structural.

**Step 8 (quality validation) intro** updates rule references:

> Hard rules H1-**H9** (was H1-H8). Any failure → refuse, name the rule + task + fix, exit.
> Soft heuristics S1-**S8** (was S1-S7). Collect as warnings.

**Step 9 (decomposition-principles audit)** gets a new bullet:

> - **Contract clarity.** Beyond H9/S8: are there contracts that *should* exist but don't? E.g., two tasks both define a `User` type independently — they should share one. Surface as a decomposition concern with the suggested fix (add a contracts-defining task that both depend on).

**Anti-patterns list** gets one entry:

> - ❌ Burying type definitions inside business-logic files when the codebase has a dedicated `contracts/` or `types/` dir — produces silent drift between two parallel implementers' invented type shapes.

### `updating-dag-plans/SKILL.md`

Three surgical edits, each anchored to a specific section already in the file:

**1. `## Hard rules` section (currently lines 93-100).** Add one new bullet adjacent to the existing immutable-history rules:

> - When adding a new task that consumes a contract defined by an already-`done` task, the new task must `depends_on:` that done task. The done task's status doesn't exempt it from H9 — sequencing rules apply for plan-coherence reasons (so a future re-execution or a reader of the plan can see the dependency). When adding a new contract-defining task, check whether existing `pending`/`ready` consumer tasks should now `depends_on:` it; if yes, mutate their `depends_on:` to include the new definer (allowed because they are `pending`/`ready`, not `done`).

**2. `## Process` step 6 (Re-run quality validation, currently lines 76-83).** Update the per-operation rule lists:

> - On **add task**: run hard rules H1-**H9** (was H1-H6) on the new task. Run soft heuristics S1, S5, **S8** on the updated DAG.
> - On **modify body**: run H1, H2, H4, H5, **H9** (was H1, H2, H4, H5) on the modified task. Run S2-S4, S6, **S8** on it.
> - (Other operations unchanged — modify `files:`, rewire `depends_on:`, remove task don't introduce new contract-symbol concerns directly. H9 and S8 are still re-checked indirectly via the global re-validation pass.)

**3. `## Required reading` section (currently lines 22-27).** Update the rule range:

> Hard rules H1-**H9** (was H1-H6) and soft heuristics S1-**S8** (was S1-S6).
>
> *(This also fixes pre-existing staleness — the file currently references H1-H6/S1-S6 even though H7 and H8 already exist. Bring it current as part of this change.)*

### `plan-quality.md` detection-algorithm section

Bump rule numbering on the existing summary list:

> 2. Run hard rules H1-**H9** (was H1-H8). Any failure → refuse, exit.
> 3. Run soft heuristics S1-**S8** (was S1-S7). Collect warnings.

## Testing

Hand-validated fixtures + manual checklist (no automated eval harness — out of scope).

### Positive fixtures (`tests/fixtures/contracts/should-pass/`)

1. `clean-explicit-contracts-task.md` — plan with a dedicated `task-contracts` root; other tasks `depends_on:` it. Should pass H9 and S8 (in a repo with `contracts/` dir).
2. `clean-implicit-sequencing.md` — plan where consumer tasks correctly `depends_on:` definers without an explicit contracts task. Should pass H9.
3. `clean-no-shared-contracts.md` — plan where each task defines its own internal types, no cross-task contract imports. Should pass H9 and S8 (no co-location violation because no sharing).
4. `clean-pre-existing-contracts.md` — plan that imports types from a file pre-existing in the codebase (not defined by any task). H9 should skip these per pre-existing edge case.
5. `h9-transitive-ok.md` — task C imports from A via `C → B → A`. Should pass (transitive closure satisfies H9).
6. `s8-schema-file-exempt.md` — plan defines types in `api.proto` alongside RPC definitions. Should pass (schema-as-code exempt from S8 Branch B).

### Refuse fixtures (`tests/fixtures/contracts/should-refuse/`)

1. `h9-missing-edge.md` — task B imports a type defined by task A; `B.depends_on` empty. Expected: H9 refusal naming the symbol and the missing edge.
2. `h9-mutual-reference.md` — A's `## Implementation` references a type defined in B AND B's references a type defined in A. Both directions need an edge, but adding both creates a cycle (caught by structural validation H1-H6). Expected: H9 refusal with suggested fix to extract the shared types into a third task that both depend on.

### Warn fixtures (`tests/fixtures/contracts/should-warn/`)

1. `s8-convention-exists-violated.md` — repo has `contracts/`, plan defines types in `src/business/processor.ts`. Expected: S8 warning (Branch A).
2. `s8-no-convention-mixed-concerns.md` — repo has no contracts dir, plan defines types alongside `fetch()` calls in same file. Expected: S8 warning (Branch B fallback).

### Manual checklist

For each fixture:

1. Note the fixture's expected outcome (pass / refuse with rule X / warn with rule Y).
2. Dispatch a fresh subagent against `writing-dag-plans` with the fixture as input.
3. Capture the output.
4. Verify the output matches the expected outcome (refusal text mentions the right rule + task + symbol; warning text mentions the right rule + task + symbol + suggestion; pass produces no quality complaints).
5. If output diverges, fix either the fixture (if expectations were wrong) or the rule spec / implementation (if behavior was wrong).

Re-run the checklist any time `plan-quality.md` or the relevant `SKILL.md` step is modified.

## Out of scope (explicit)

- Runtime contracts (DB schema, events, env vars, CLI). Future S-rule candidate.
- Auto-mutation of plans to fix violations.
- Automated eval harness for the new rules.
- Changes to `superpowers:writing-plans` upstream — the spec is structured to allow a port, but the port itself is a separate piece of work.
- Changes to `plan-format.md` or any executor/implementer agent definitions.

## Open questions / risks

- **False positives on direct-usage detection (Pass 2, secondary signal).** Token-based scanning for type names in code blocks may misclassify identifiers that happen to match a definer's symbol name. Mitigation: rank import-based detection above direct-usage detection in the refusal output; if only direct-usage triggers a violation, present it more cautiously and offer the user an "ignore this match" path. Refine after first real-world use.
- **Contracts-dir auto-detection in monorepos.** A monorepo may have multiple `contracts/` dirs across packages. The current spec treats them all as valid — symbols can live in any of them. If this proves too permissive (e.g., a `packages/api/contracts` symbol used by `packages/web/` should ideally live in a shared location), refine in a follow-up.
- **Schema-file extension list.** The exempt list (`.proto`, `.openapi.yaml`, `.graphql`, etc.) is informed by common conventions but not exhaustive. New formats (e.g., AsyncAPI, JSON Schema files at top level) may need additions over time.
