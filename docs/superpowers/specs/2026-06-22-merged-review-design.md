# Merged Review for Small Tasks — Design Spec

**Date:** 2026-06-22
**Skills targeted:** `parallel-dag-execution:writing-dag-plans`, `parallel-dag-execution:updating-dag-plans`, `parallel-dag-execution:executing-dag-plans`. Plus a new reviewer agent and a new dispatch template.

**Dependency:** This builds on the token-optimization work (PR #1, branch `feat/token-optimization` — tier hints, `resolve_tier`/`resolve_model`, S9, validation rules #7/#8). Implementation MUST land after that PR merges; this spec references those artifacts as existing.

## Goal

Cut review cost **and** wall-clock latency for small, mechanical tasks by collapsing the two-call spec→quality review chain into **one** combined reviewer call — opt-in per task, defaulting to today's two-call behavior. No regression to review rigor: the merged reviewer performs both checks and returns both verdicts.

## Why

Today every task — even a docs-only one — pays two sequential reviewer subagent dispatches (`executing-dag-plans/SKILL.md` §Per-task review chain): implementer DONE → spec reviewer → quality reviewer. That is two round-trips of latency and two reviewer token bills per task on the clean path. The token-optimization work downshifts reviewer *models* but never reduces the *number* of review calls.

For a small mechanical change (rename, doc edit, fixture addition), the spec-first-then-quality ordering buys little: spec issues are rare and their fixes are tiny, so the "fix spec, then quality-review the corrected code" sequencing almost never fires. Merging the two reviews into one call on these tasks roughly **halves** review cost and latency for them, with no rigor loss because:

- The merged reviewer still runs both Part 1 (spec compliance) and Part 2 (code quality) and returns both verdicts.
- On ISSUES, the implementer fix re-dispatches through a merged **re-review** on the corrected diff — so the approved state is always quality-reviewed-on-final-code, exactly as today.

The ordering only ever mattered when a spec fix changes code; eligibility (below) excludes exactly those tasks.

## Why merge, not skip or parallelize

- **Skip quality entirely** (for trivial tasks): merge *dominates* it — merging still runs the quality check (one call) rather than dropping it, so it captures nearly the same savings without a rigor hole.
- **Parallel spec+quality**: saves latency, not tokens, and wastes the quality call whenever spec review changes the code. Lower value-to-risk.

Both are explicit non-goals.

## Non-goals

- **Skipping quality review.** Rejected in favor of merge (above).
- **Parallel spec+quality dispatch.** Rejected (above).
- **An executor "diff too big → fall back to split" safety threshold.** Deliberately omitted (YAGNI). The merged reviewer runs both checks even on a large diff, and `merged` is opt-in/heuristic-gated to low-risk tasks; a threshold reintroduces the arbitrary-cutoff problem. If an author force-marks a large task `merged`, that is their call, and rigor is still preserved (both checks run).
- **Touching the BLOCKED auto-retry-once ladder.** Implementer-side; unaffected.
- **Auto-writing `review_mode` silently.** S10 surfaces a suggestion; the author types it (mirrors S9).
- **Changing the existing two-call chain's behavior.** `split` remains the default and behaves identically to today.

## Architecture

All changes are additive. A plan with no `review_mode` field anywhere validates, dispatches, and reviews exactly as today (`split` everywhere).

| File | Change |
|---|---|
| `skills/writing-dag-plans/plan-format.md` | Add `default_review_mode` to plan-level frontmatter and `review_mode` to per-task YAML schema (enum `merged \| split`, default `split`). Add §Review-mode resolution (resolver + which reviewer tier governs a merged review). Add validation rules #9 (per-task `review_mode` enum) and #10 (plan-level `default_review_mode` enum). |
| `skills/writing-dag-plans/plan-quality.md` | Add soft heuristic **S10** (suggest `merged` for clearly-mechanical low-risk tasks). Update §Detection algorithm step to include S10. |
| `skills/writing-dag-plans/SKILL.md` | Update §Required reading + soft-heuristic range references to include S10. |
| `skills/updating-dag-plans/SKILL.md` | Add "Modify review mode" and "Modify plan-level default review mode" operation rows (mutable on `pending`/`ready`). Update §Required reading + §Process quality-revalidation step. |
| `skills/executing-dag-plans/SKILL.md` | In §Per-task review chain, branch on resolved `review_mode`: `split` → existing spec→quality chain; `merged` → one `dag-merged-reviewer` dispatch. Add `review_mode` to the pre-flight validation. Document the merged reviewer's model tier (= the `quality_reviewer` tier). |
| `agents/dag-merged-reviewer.md` | NEW agent. `model: sonnet` fallback, `skills: [requesting-code-review]` (same as quality reviewer). Persona does both spec compliance and code quality, returns both verdicts. |
| `skills/executing-dag-plans/merged-reviewer-prompt.md` | NEW dispatch template fusing the spec-reviewer and quality-reviewer templates: Part 1 spec compliance (bidirectional), Part 2 code quality, both verdicts. Cache-friendly section order, literal Agent invocation with `model: resolve_model(resolve_tier(task, "quality_reviewer"))`. |
| `tests/fixtures/review-mode/should-pass/*.md` | Conformance fixtures (valid merged / split / hybrid plans). |
| `tests/fixtures/review-mode/should-warn/*.md` | S10 warn fixtures. |
| `tests/fixtures/review-mode/should-refuse/*.md` | #9/#10 enum-violation fixtures. |

**What stays the same:** file-scope tripwire, parallel-dispatch contract, BLOCKED ladder, the `split` two-call chain, failure cascade, resumability, mermaid/ASCII formats, every existing H/S rule and validation rule, the tier system from PR #1.

## Schema

### Plan-level frontmatter

```yaml
---
title: my-feature
created: 2026-06-22
default_review_mode: split   # OPTIONAL. merged | split. Default `split` (today's two-call chain).
---
```

### Per-task YAML

```yaml
id: task-N
depends_on: []
files: [path/to/file.ts]
status: pending
review_mode: merged          # OPTIONAL. merged | split. Falls back to default_review_mode, then `split`.
```

### Review-mode resolution

A resolver parallel to the tier resolver from PR #1:

```
resolve_review_mode(task) =
    task["review_mode"]                       if present
    else plan_frontmatter["default_review_mode"] if present
    else "split"
```

**Reviewer tier for a merged review:** a merged review does both jobs, so it resolves its model via the **`quality_reviewer`** tier (the more demanding role) — `resolve_model(resolve_tier(task, "quality_reviewer"))`. No new tier field. (When `review_mode: split`, the spec and quality reviewers resolve their own tiers as today.)

### Validation rules added to `plan-format.md`

9. **Per-task review-mode enum.** `review_mode`, when present on any task, MUST be `merged | split`. Any other value → refuse naming the task id, field, and bad value.
10. **Plan-level review-mode enum.** `default_review_mode`, when present in frontmatter, MUST be `merged | split`. Any other value → refuse naming the field and bad value.

Both use the existing rules-1-8 refusal-message format.

## Eligibility — soft heuristic S10

Lives in `plan-quality.md` alongside S1–S9. Same warn-and-confirm pattern; single-direction (only ever nudges *safe* tasks toward `merged`, never the reverse).

**S10 — review-mode suggestion.** Suggest `review_mode: merged` for a task when ALL hold:
- The task is **clearly mechanical** — reuses S9's mechanical signals: `files:` all match docs-only / fixture-only / test-data globs (`**/*.md`, `**/test/fixtures/**`, `**/tests/data/**`, `**/CHANGELOG*`, `**/README*`), OR title/body matches `\b(rename|format|move|copy|extract|inline|docs?[-_]only|test[-_]data|fixture[-_]only)\b`; AND
- The task trips **none** of S9's risk signals — novelty regex (`\b(algorithm|protocol|state machine|consensus|concurrency|race|lock|transaction|cryptograph|atomicity)\b`), `## Why this abstraction` heading, or security-path globs (`**/auth/**`, `**/security/**`, `**/crypto/**`, `**/payments/**`, `**/session*`); AND
- `resolve_review_mode(task)` currently resolves to `split`.

Suggested action: `review_mode: merged`. The author confirms or skips (joins the batched "save anyway? (y/N)" prompt, default N). S10 **never** auto-writes the field.

S10 reuses S9's signal definitions verbatim so the two heuristics stay coherent; a note in both records that S9 governs *tier* and S10 governs *review mode*, sharing the same risk-signal vocabulary.

## The merged reviewer

### Agent — `agents/dag-merged-reviewer.md`

- `model: sonnet` (safe fallback when the executor passes nothing).
- `skills: [requesting-code-review]` (same auto-load as `dag-quality-reviewer`, for the quality half).
- Persona: reviews one task's diff for BOTH spec compliance (bidirectional under/over-build — acceptance criteria in the task body ARE the spec) AND code quality (correctness, clarity, maintainability, test quality), returning both verdicts. Read-only on the checkout.

### Dispatch template — `skills/executing-dag-plans/merged-reviewer-prompt.md`

The two existing reviewer templates fused, in cache-friendly order (stable content first, per the PR #1 reordering convention):

1. Stable preamble (role: combined spec + quality review of one task).
2. Project conventions (if any).
3. Output spec — **both** verdicts: Spec Compliance (APPROVED / ISSUES) and Code Quality (APPROVED / ISSUES with severity).
4. Task spec (id, files).
5. Task body (binding for spec; context for quality).
6. Implementation under review (commit SHA + `git show` command).
7. Re-dispatch addenda last.

Plus a literal Agent invocation example:

```
Agent({
  description: "Merged-review task-3",
  subagent_type: "dag-merged-reviewer",
  model: resolve_model(resolve_tier(task, "quality_reviewer")),
  prompt: <constructed-from-template-above>
})
```

**Output contract:** the merged reviewer returns two verdicts. The task is `done` only when BOTH are APPROVED. If EITHER reports ISSUES, the implementer is re-dispatched with the combined issue list, then a merged **re-review** runs on the new diff.

## Executor flow (executing-dag-plans)

In §Per-task review chain, after the implementer reports DONE, branch on `resolve_review_mode(task)`:

```
implementer DONE
  → review_mode == "split" (default):
      dispatch dag-spec-reviewer
        → APPROVED → dispatch dag-quality-reviewer
            → APPROVED → mark done
            → ISSUES → re-dispatch implementer (quality feedback) → loop
        → ISSUES → re-dispatch implementer (spec feedback) → loop
  → review_mode == "merged":
      dispatch dag-merged-reviewer (model = quality_reviewer tier)
        → both APPROVED → mark done
        → either ISSUES → re-dispatch implementer (combined feedback) → merged re-review → loop
```

- **Pre-flight:** extend the existing tier pre-flight to also validate every `review_mode` / `default_review_mode` ∈ `{merged, split}`; halt naming the offending task id (or `plan-level`) + field + value. No silent fallback.
- **Composition with BLOCKED ladder:** unchanged — the ladder is implementer-side and fires before review regardless of review mode.
- **Composition with the tier system:** a merged review's model comes from the `quality_reviewer` tier; `spec_reviewer_hint` is simply unused when a task is `merged` (documented, not an error).

## Updating-plans (mid-flight mutations)

Two rows added to `updating-dag-plans/SKILL.md` §Operations supported:

| Op | Pre-condition | Behavior |
|---|---|---|
| **Modify review mode** (`review_mode`) | Target's status is `pending` or `ready` | Update YAML field. Re-validate enum (rule #9). No mermaid re-render (label doesn't show review mode). |
| **Modify plan-level default review mode** (`default_review_mode`) | At least one task is `pending`/`ready` | Update frontmatter. Re-validate enum (rule #10). Affects all tasks lacking a per-task override and not yet immutable. Refuse if every task is immutable. |

`ready` is mutable for `review_mode` for the same reason as tier hints: it doesn't interact with the parallelism contract; the next tick reads fresh state and dispatches the resolved review mode. `running`/`done`/`failed`/`skipped` remain immutable.

## Error handling

- **Invalid `review_mode` past pre-flight** → executor halts naming task id + field + value. No silent fallback to `split`.
- **`dag-merged-reviewer` not in the agent registry** → caught by the existing implementer-registry-style pre-flight (extend it to also require `dag-merged-reviewer` whenever any task resolves to `merged`). Halt with a clear deploy-the-agent message.

## Migration

None. Plans without `review_mode` resolve to `split` everywhere = today's two-call chain. Existing token-optimization fixtures and contract fixtures are unaffected.

## Testing

Fixtures under `tests/fixtures/review-mode/{should-pass,should-warn,should-refuse}/`, mirroring the tier-fixture pattern. Each fixture carries an `<!-- EXPECTED: ... -->` verdict comment, validated by applying the skill procedure (no runner).

### should-pass
- `clean-no-review-mode.md` — no `review_mode` anywhere; resolves to `split` (regression / no-migration).
- `clean-plan-level-merged.md` — `default_review_mode: merged`; all tasks inherit.
- `clean-per-task-merged.md` — one task `review_mode: merged`, no plan-level default.
- `clean-hybrid.md` — `default_review_mode: merged` + a task overriding to `split`.

### should-warn (S10)
- `s10-docs-only-no-merged.md` — docs-only task, no `review_mode` → suggest `merged`.
- `s10-fixture-only-no-merged.md` — fixture-only task → suggest `merged`.
- `s10-mechanical-but-security.md` — mechanical signal BUT a security-path file. Negative control for S10: the EXPECTED verdict is a warning that does NOT include an S10 merge suggestion (the security risk signal suppresses S10). Note that S9 may independently warn on this task (security path → tier upshift); the fixture's assertion is specifically "no S10 suggestion present," demonstrating S10 suppression by a risk signal.

### should-refuse
- `bad-task-review-mode-typo.md` — `review_mode: combined` → rule #9.
- `bad-plan-default-typo.md` — `default_review_mode: both` → rule #10.

### Behavioral checks (not fixtures — reasoned against the skills)
- No-`review_mode` plan dispatches the two-call chain identically to today.
- A `merged` task dispatches one `dag-merged-reviewer`; `done` only when both verdicts APPROVED; either-ISSUES re-dispatches the implementer then merged-re-reviews.
- Merged reviewer resolves its model via the `quality_reviewer` tier.
- `review_mode` mutation accepted on `pending`/`ready`, refused on `running`.

## Summary

| Lever | Mechanism | Risk to rigor / parity |
|---|---|---|
| Merge spec+quality for small tasks | New `review_mode` field + `default_review_mode` + S10 suggestion + `dag-merged-reviewer` agent/template; executor branches on resolved mode | None — both checks still run and re-run on the corrected diff; default `split` = today; opt-in and heuristic-gated to low-risk tasks |

The design adds one opt-in lever that halves review cost/latency for clearly-mechanical tasks, behind a `split` default that preserves today's two-call rigor exactly, and reuses the PR #1 tier resolver and S9 risk-signal vocabulary for full coherence.
