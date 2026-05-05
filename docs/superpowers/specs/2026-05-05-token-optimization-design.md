# Token-Use Optimization for Parallel DAG Execution — Design Spec

**Date:** 2026-05-05
**Skills targeted:** `parallel-dag-execution:writing-dag-plans`, `parallel-dag-execution:updating-dag-plans`, `parallel-dag-execution:executing-dag-plans`. Plus the three dispatch templates and the agent definitions, surgically.

## Goal

Reduce input-token spend across a DAG run **without regressing first-pass implementer success rate**. Three additive levers, all conservative by default:

1. **Prompt-cache friendliness** — re-order subagent dispatch templates so stable content (project conventions, output spec) sits at the front of the user message, where prompt caching pays off.
2. **Per-task implementer tier wiring** — wire the existing `model_hint` field to the actual `Agent`-tool dispatch (today it's dead weight on first dispatch; only the BLOCKED-retry path mentions `model:`).
3. **Hybrid reviewer tier hints** — add `default_spec_reviewer_hint` / `default_quality_reviewer_hint` plan-level frontmatter and `spec_reviewer_hint` / `quality_reviewer_hint` per-task overrides. Reviewers are the biggest single token sink (run on every implementer dispatch, sometimes twice) and today are hardcoded to `sonnet`.

## Why

Two structural facts in the codebase as of today drive the wasted spend:

- **`model_hint` is dead weight on first dispatch.** `skills/writing-dag-plans/plan-format.md:85` defines `model_hint: cheap | standard | opus` and `skills/executing-dag-plans/implementer-prompt.md:87-107` defines a BLOCKED-retry tier-upgrade ladder, but `skills/executing-dag-plans/SKILL.md:33-36` (the dispatch site) never mentions a `model:` parameter. The executor sends the dispatch to whatever `model:` the agent definition file declares — `sonnet` for all three subagent types — regardless of the task's hint. Authors who set `model_hint: cheap` get no first-dispatch savings; the field only takes effect after a hard failure.
- **Reviewers run on every task, hardcoded `sonnet`.** `agents/dag-spec-reviewer.md:4` and `agents/dag-quality-reviewer.md:4` both pin `model: sonnet`. A clean task is 3 sonnet calls (impl + spec + quality); a task with one review cycle is 5+. Spec review is rule-based and a strong candidate for selective downshift; quality review is judgment-heavy and stays at `standard`+. Without a per-role hint, every task pays the full sonnet cost on review regardless of complexity.

Caching is the orthogonal pure-win lever. Today's three dispatch templates put per-task content (task spec, body, upstream context) before stable content (project conventions, output format). Re-ordering them so stable content comes first lets even modest harness-level caching capture the largest blocks across all dispatches in a tick.

The accuracy bar is **first-pass parity**: first implementer dispatch must succeed at today's rate. That rules out aggressive defaults (haiku-by-default, fail-forward via the BLOCKED ladder) and forces optimization to come from cheaper-but-still-capable choices the author opts into deliberately, plus the cache reorder.

## Non-goals

- **Token telemetry.** No in-repo measurement of "did this save tokens." Verifying the savings empirically is a follow-up that needs telemetry plumbing; this spec is correctness-only.
- **Upstream-deps context compression.** Discussed and explicitly declined as a scope expansion — keeps this spec focused on the three levers above.
- **Stoa MCP comm-layer migration.** Orthogonal architectural change; deferred to its own spec if pursued.
- **Multi-breakpoint caching with explicit `cache_control` markers.** The Agent tool today does not expose `cache_control` to the dispatching controller; this spec relies on prompt-template ordering and harness-level caching of agent system prompts. If `cache_control` becomes exposed later, the breakpoint placement is documented in §Architecture so a follow-up is a small change, not a re-architecture.
- **Changing the BLOCKED-retry tier-upgrade ladder.** It already composes correctly with per-task tiers; this spec leaves it untouched.
- **Fail-forward escalation on review-issue cycles.** Considered and rejected — would violate first-pass parity if a too-cheap implementer tier ping-pongs through reviews.
- **Touching `agents/dag-implementer.md` / `dag-spec-reviewer.md` / `dag-quality-reviewer.md` model declarations.** Their `model: sonnet` line stays — it's the safe fallback when the executor passes nothing.
- **Per-task auto-population of tier hints by the skill.** S9 surfaces suggestions; the author types them in.

## Architecture

All changes are additive. Existing plans without any new fields validate, dispatch, and execute identically to today.

| File | Change |
|---|---|
| `skills/writing-dag-plans/plan-format.md` | Add `default_model_hint`, `default_spec_reviewer_hint`, `default_quality_reviewer_hint` to the plan-level frontmatter schema. Add `spec_reviewer_hint`, `quality_reviewer_hint` to the per-task YAML schema. Add §"Tier resolution" with the resolver pseudocode and the tier→model table. Add validation rules #7 (per-task hint enum) and #8 (plan-level default enum) to §Validation rules. |
| `skills/writing-dag-plans/plan-quality.md` | Add S9 (tier-complexity mismatch) to soft heuristics table with the five detection patterns. Update detection-algorithm step list to include S9. |
| `skills/writing-dag-plans/SKILL.md` | Add a step between current steps 6 and 7: "Optional plan-level tier prompt" (described below). Update §Required reading and §step references to mention the new fields. |
| `skills/updating-dag-plans/SKILL.md` | Add "Modify tier hint" and "Modify plan-level default hint" rows to §Operations supported. Update §Required reading. Add refusal example for `running` tier-hint mutation. |
| `skills/executing-dag-plans/SKILL.md` | Update §Execution model step 4 to describe tier resolution and the `model:` parameter on the Agent dispatch. Update §Per-task review chain to describe reviewer tier resolution. Add a §Pre-flight tier-validation bullet alongside the existing implementer-registry pre-flight. |
| `skills/executing-dag-plans/implementer-prompt.md` | Re-order the prompt template: stable preamble → project conventions → output format spec → task spec → task body → upstream context → re-dispatch addenda last. Add an explicit literal `Agent`-tool invocation example showing the `model:` parameter. Existing BLOCKED-retry table stays. |
| `skills/executing-dag-plans/spec-reviewer-prompt.md` | Same re-ordering as implementer-prompt. Add literal Agent invocation with `model:` param. |
| `skills/executing-dag-plans/quality-reviewer-prompt.md` | Same re-ordering as implementer-prompt. Add literal Agent invocation with `model:` param. |
| `tests/fixtures/tiers/should-pass/*.md` | 5 fixtures (see §Testing). |
| `tests/fixtures/tiers/should-warn/*.md` | 4 S9 fixtures. |
| `tests/fixtures/tiers/should-refuse/*.md` | 3 hard-rule violation fixtures. |

**What stays the same:** file-scope tripwire, parallel-dispatch contract, BLOCKED auto-retry-once ladder, review chain (spec → quality), failure cascade, resumability semantics, mermaid-block format, ASCII-tree format, every existing H/S rule.

## Schema

### Plan-level frontmatter

```yaml
---
title: my-feature
created: 2026-05-05
default_model_hint: standard            # OPTIONAL. cheap | standard | opus. Default `standard`. Implementer tier.
default_spec_reviewer_hint: standard    # OPTIONAL. cheap | standard | opus. Default `standard`.
default_quality_reviewer_hint: standard # OPTIONAL. cheap | standard | opus. Default `standard`.
---
```

All three keys are optional. Omitting any (or the entire trio) keeps today's behavior — `standard` everywhere.

### Per-task YAML

```yaml
id: task-N
depends_on: []
files: [path/to/file.ts]
status: pending
model_hint: cheap                # OPTIONAL. EXISTING field. Implementer tier. Falls back to default_model_hint, then `standard`.
spec_reviewer_hint: cheap        # OPTIONAL. NEW. Spec reviewer tier. Falls back to default_spec_reviewer_hint, then `standard`.
quality_reviewer_hint: opus      # OPTIONAL. NEW. Quality reviewer tier. Falls back to default_quality_reviewer_hint, then `standard`.
implementer: dag-implementer     # OPTIONAL. EXISTING.
single_threaded: false           # OPTIONAL. EXISTING.
is_wiring_task: false            # OPTIONAL. EXISTING.
```

### Tier resolution

Single resolver used at all three dispatch sites:

```
resolve_tier(task, role) =
    task[role + "_hint"]                              if present
    else plan_frontmatter["default_" + role + "_hint"] if present
    else "standard"

resolve_model(tier) =
    "haiku"  if tier == "cheap"
    "sonnet" if tier == "standard"
    "opus"   if tier == "opus"
```

Role values when calling `resolve_tier`:
- `model` for the implementer (per-task field is the existing `model_hint`, plan-level default is `default_implementer_hint`). Naming asymmetry is intentional — `model_hint` predates this spec — and the resolver handles it explicitly.
- `spec_reviewer` for spec review.
- `quality_reviewer` for quality review.

### Validation rules added to `plan-format.md`

7. **Per-task hint enum.** `model_hint`, `spec_reviewer_hint`, `quality_reviewer_hint`, when present on any task, MUST be one of `cheap | standard | opus`. Any other value → refuse save with the offending task id, field name, and the bad value.
8. **Plan-level default enum.** `default_model_hint`, `default_spec_reviewer_hint`, `default_quality_reviewer_hint`, when present in frontmatter, MUST be one of `cheap | standard | opus`. Any other value → refuse with the field name and the bad value.

Both rules use the existing refusal-message format used for rules 1-6.

## Authoring UX (writing-dag-plans)

### Optional plan-level tier prompt

Added between current step 6 (structural validation passes) and step 7 (quality validation). The skill computes a per-task complexity classification:

- **Mechanical signals:** title or body matches `\b(rename|format|move|copy|extract|inline|docs?[-_]only|test[-_]data|fixture[-_]only)\b`; OR `files:` consists entirely of `**/*.md`, `**/test/fixtures/**`, `**/tests/data/**`, `**/CHANGELOG*`, `**/README*`.
- **Novelty signals:** body contains `\b(algorithm|protocol|state machine|consensus|concurrency|race|lock|transaction|cryptograph|atomicity)\b`; OR `## Why this abstraction` heading present; OR `files:` overlaps `**/auth/**`, `**/security/**`, `**/crypto/**`, `**/payments/**`, `**/session*`.

Compute `mechanical_pct` and `novelty_pct` over all tasks in the plan. If `mechanical_pct > 70%` AND `novelty_pct < 10%`, prompt:

> Most tasks in this plan look mechanical. Set plan-level reviewer default to `default_spec_reviewer_hint: cheap`? (y/N — default N)

Otherwise: skip the prompt entirely. S9 will surface per-task suggestions on individual tasks where signals warrant.

The skill **never** auto-writes plan-level defaults silently. Author confirms or skips.

### Soft heuristic S9 — tier-complexity mismatch

Lives in `plan-quality.md` alongside S1–S8. Same warn-and-confirm pattern.

| Trigger | Suggested action |
|---|---|
| Files all match docs-only / fixture-only / test-data patterns AND body <200 words AND `model_hint` resolves to `standard` | Suggest `model_hint: cheap` |
| Body matches novelty-signal regex (above) AND `model_hint` resolves to `standard` | Suggest `model_hint: opus` AND `quality_reviewer_hint: opus` |
| `files:` overlaps security-path globs (above) AND `quality_reviewer_hint` resolves below `opus` | Suggest `quality_reviewer_hint: opus` |
| `## Why this abstraction` section present AND `model_hint` resolves to `standard` | Suggest `model_hint: opus` |
| `is_wiring_task: true` AND wiring spans >2 distinct subsystem prefixes AND `quality_reviewer_hint` resolves below `opus` | Suggest `quality_reviewer_hint: opus` |

Each warning names the task id, the signal that fired, the suggested tier change, and joins the existing batched "save anyway? (y/N)" prompt (default N).

S9 is single-direction:
- Suggests **upshifts** where signals indicate elevated risk.
- Suggests **downshifts only for clearly-mechanical tasks** — never for ambiguous ones.

This protects the first-pass-parity bar.

### What the skill explicitly does NOT do

- Does not prompt per-task during decomposition. Tier choice is a low-priority field; per-task pestering would tank the writing-dag-plans UX.
- Does not auto-write per-task hint fields based on heuristics. S9 surfaces; the author types.
- Does not hard-refuse on tier mismatch. All tier guidance is soft (warn + confirm).

## Dispatch wiring (executing-dag-plans)

### Tier resolution at every dispatch

The single resolver above runs at three sites:

1. **Initial implementer dispatch** (`SKILL.md` §Execution model step 4). Pass `model: resolve_model(resolve_tier(task, "model"))` to the Agent tool.
2. **Spec reviewer dispatch** (`SKILL.md` §Per-task review chain). Pass `model: resolve_model(resolve_tier(task, "spec_reviewer"))`.
3. **Quality reviewer dispatch** (same section). Pass `model: resolve_model(resolve_tier(task, "quality_reviewer"))`.

Composition with existing flows:
- **BLOCKED-retry ladder** still bumps one tier from the resolved tier. A `cheap` implementer that BLOCKs retries at `standard`; a `standard` retries at `opus`; an `opus` skips retry and the task goes straight to `failed`. No schema change.
- **Review-issue re-dispatch** uses the **original resolved tier**, not the BLOCKED-upgraded one. Only BLOCKED upgrades. Documented inline in `implementer-prompt.md` §Re-dispatch on review issues.

### Prompt template re-ordering

All three dispatch templates (`implementer-prompt.md`, `spec-reviewer-prompt.md`, `quality-reviewer-prompt.md`) are re-ordered so the user-message content begins with stable blocks:

```
1. Stable preamble — one line identifying role + pipeline (constant per role).
2. Project conventions — full CLAUDE.md (constant per plan run).
3. Output format spec — DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED instructions (constant per role).
4. Task spec — id, files, depends_on (varies per task).
5. Task body (varies per task).
6. Upstream context (varies per task).
7. Re-dispatch addenda — review-issue list or BLOCKED report (most volatile, last).
```

The semantic content is unchanged. Only the order in which sections appear in the dispatched user message changes. If the Agent tool ever exposes `cache_control` to the controller, the breakpoint goes after section 3 — no template re-architecture needed.

### Literal Agent invocation example

Each dispatch template gains an explicit example showing the controller's `Agent` tool call:

```
Agent({
  description: "Implement task-3",
  subagent_type: task.implementer ?? "dag-implementer",
  model: resolve_model(resolve_tier(task, "model")),
  prompt: <constructed-from-template-above>
})
```

This is a documentation change, not a code change — `executing-dag-plans` is itself a skill executed by an LLM controller, so the "wiring" is teaching the controller LLM to include the `model:` field at dispatch time.

### Pre-flight tier validation

`executing-dag-plans/SKILL.md` already pre-flights `implementer:` values against the harness's agent registry. Add an analogous pre-flight: validate every `*_hint` value across every task and every plan-level default is in `{cheap, standard, opus}`. Halt with a clear error naming the offending field and value if any check fails. This catches authoring bugs that slipped past the writing-dag-plans validator (e.g., the plan was authored on a different machine and modified by hand).

## Updating-plans (mid-flight mutations)

Two new rows added to `updating-dag-plans/SKILL.md` §Operations supported:

| Op | Pre-condition | Behavior |
|---|---|---|
| **Modify tier hint** (`model_hint`, `spec_reviewer_hint`, `quality_reviewer_hint`) | Target's status is `pending` or `ready` | Update YAML field. Re-validate enum (`cheap | standard | opus`). No mermaid re-render needed (label doesn't show tier). |
| **Modify plan-level default hint** (`default_*_hint` in frontmatter) | At least one task in the plan has status `pending` or `ready` | Update frontmatter field. Re-validate enum. Affects all tasks lacking a per-task override AND not yet `running`/`done`/`failed`/`skipped`. Refuse if every task is already in an immutable status. |

**Why `ready` is mutable for tier hints (unlike `files:`):** Today `files:` is mutable only on `pending` because `ready` tasks queue for the very next dispatch tick and a file-scope change there could conflict with already-`running` siblings. Tier hints have no such conflict — they don't interact with the parallelism contract. Mutating a `ready` task's tier between ticks is safe; the next tick reads fresh state and dispatches with the new resolved tier.

**Refusal example added:**

```
✗ Refused: Cannot modify task-3.model_hint (status: running)
   An implementer subagent is currently executing this task at its
   originally-resolved tier. Wait for completion (or BLOCKED), then
   the BLOCKED-retry ladder will pick up the new value if you've
   updated it by then.
```

## Error handling

Three new runtime error paths in `executing-dag-plans`:

1. **Invalid tier value past pre-flight.** Resolver throws; executor halts with the offending task id and field name. **No silent fallback to `standard`** — silent fallbacks hide bugs.
2. **Tier resolves to a model the harness rejects** (e.g., `opus` or `haiku` not available in the running Claude Code version). Agent tool returns an error; executor reports a hard halt naming the rejected model and the offending task/field, with a generic fix message: "model `<name>` rejected by harness; choose a different tier or upgrade Claude Code." Config issue, not task failure.
3. **Per-task hint references a tier inconsistent with plan-level default.** Not an error — per-task overrides bypass plan-level defaults entirely. Documented explicitly in `plan-format.md` §Tier resolution.

All three are surfaced via the existing executor halt mechanism. No new mechanisms.

## Testing

Fixture layout parallels existing `tests/fixtures/contracts/{should-pass, should-warn, should-refuse}/` pattern. New top-level dir: `tests/fixtures/tiers/`.

### should-pass (5 fixtures)

| Fixture | Purpose |
|---|---|
| `clean-no-hints.md` | Plan with no tier hints anywhere. Today's behavior; must validate, must dispatch identically. Regression test for the no-migration claim. |
| `clean-plan-level-only.md` | Plan with only plan-level defaults set. All tasks inherit. |
| `clean-per-task-only.md` | Plan with only per-task hints, no plan-level defaults. Per-task fields used directly. |
| `clean-hybrid.md` | Plan with both — per-task overrides plan-level on a subset of tasks. Verifies override precedence. |
| `clean-mixed-tiers.md` | Plan with mechanical task at `cheap`, complex task at `opus`, others default. Realistic. |

### should-warn (4 S9 fixtures)

| Fixture | S9 trigger |
|---|---|
| `s9-mechanical-no-cheap.md` | Docs-only task, body <200 words, no `model_hint` set. |
| `s9-security-no-opus.md` | Task touching `src/auth/session.ts`, `quality_reviewer_hint` resolves below `opus`. |
| `s9-novelty-phrase.md` | Task body mentions "consensus algorithm", no tier upshift. |
| `s9-multi-system-wiring.md` | `is_wiring_task: true` spanning `src/api/`, `src/ui/`, `src/jobs/`, no quality upshift. |

### should-refuse (3 hard-rule fixtures)

| Fixture | Rule violated |
|---|---|
| `bad-task-hint-typo.md` | `model_hint: medium` — invalid tier. Rule #7. |
| `bad-plan-default-typo.md` | `default_spec_reviewer_hint: pro` in frontmatter. Rule #8. |
| `bad-hint-type-mismatch.md` | `quality_reviewer_hint: 0` — integer where enum string required. Rule #7. |

### Behavioral tests (not fixtures — actual dispatch)

| Test | Verifies |
|---|---|
| BLOCKED-retry composes with per-task tier | `cheap` BLOCKs → retries at `standard`; second BLOCKED → fails. No skip-of-tiers. |
| Review-issue re-dispatch uses original tier | A `cheap` implementer reporting via `ISSUES` re-dispatches at `cheap`, not `standard`. |
| Mutating `model_hint` on `pending` accepted | Fresh dispatch at the new tier on next tick. |
| Mutating `model_hint` on `running` refused | With the documented refusal message. |
| Plan with no hints dispatches identically to today | Regression test for the no-migration claim. |

### What's intentionally NOT tested

- **Actual token-cost reduction.** Telemetry is out of scope; correctness is verified via behavior parity + tier resolution + caching-order.
- **Cache hit rates.** Same reason. The prompt-template re-ordering is structurally correct; whether the harness/API caches it well is observable only via telemetry.

## Migration

None. Existing plans continue to validate and execute identically:

- Old plans without any hints → all tiers resolve to `standard` (= `sonnet`) = today's behavior, plus the cache-friendly re-ordering benefit.
- Old plans with `model_hint: cheap` or `model_hint: opus` set → **behavior change.** First dispatch will now go to the hinted tier (haiku or opus), where today it goes to `sonnet` regardless. This is the intended fix — the field has always been documented as taking effect on first dispatch, but the wiring wasn't there. Authors who set this field expecting the documented behavior get it after this lands. Authors who set it without realizing it was a no-op should review their plans before re-running them: if you set `cheap` because "it didn't matter," remove the field; if you set it because "I want haiku here," no action needed.
- Old plans with `model_hint: standard` set → no change (`standard` resolves to `sonnet`, which the agent file also defaults to).
- Existing fixtures in `tests/fixtures/contracts/` are unaffected; they test orthogonal rules.

## Summary

| Lever | Mechanism | Risk to first-pass parity |
|---|---|---|
| Prompt-cache friendliness | Re-order three dispatch templates so stable content sits at the front | None — content unchanged |
| Per-task implementer tier wiring | Resolver + `model:` param on Agent tool dispatch | None — defaults to `standard` (= today's `sonnet`) |
| Hybrid reviewer tier hints | New plan-level defaults + per-task overrides + reviewer-side resolver | None when defaults stay at `standard`; opt-in only |
| S9 soft heuristic | Warn-and-confirm at save | None — guidance only, single-direction (upshift suggestions; downshift only for clearly-mechanical tasks) |

The design closes the dead-weight gap on `model_hint`, opens reviewer tiering as an opt-in lever (the largest single token sink), and re-orders prompts for cache friendliness — all behind defaults that preserve today's first-pass behavior.
