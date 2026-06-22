# Task 9 Report — Cross-reference consistency sweep + minor fixes

## Part A — Sweep Results

### Step 1: Enum-consistency sweep

Command: `grep -rnE "cheap|standard|opus|haiku|sonnet" skills/ | grep -iE "hint|tier|resolve_model"`

**Verdict: CLEAN — no drift.**
Every occurrence of the tier enum uses exactly `cheap | standard | opus`. Model mapping (`cheap→haiku`, `standard→sonnet`, `opus→opus`) is consistent across `plan-format.md`, `executing-dag-plans/SKILL.md`, and all three prompt templates. No ambiguous synonyms or alternate spellings found.

### Step 2: Resolver-reference sweep

Command: `grep -rn "resolve_tier\|resolve_model" skills/`

**Verdict: CLEAN — no divergent re-definitions.**
`resolve_tier` and `resolve_model` are defined exactly once in `skills/writing-dag-plans/plan-format.md` §Tier resolution. All references in `executing-dag-plans/SKILL.md` (lines 33, 53) and the three prompt templates (`implementer-prompt.md:85`, `spec-reviewer-prompt.md:72`, `quality-reviewer-prompt.md:72`) are invocations, not re-definitions. `plan-quality.md` also references `resolve_tier` by name in S9 (correct — it consumes the resolver, doesn't re-define it).

### Step 3: Rule-number sweep

Command: `grep -rnE "S1-S8|S1-S6|rules 1-6|H1-H8" skills/`

**Drift found:** `skills/writing-dag-plans/SKILL.md:140` contained `"rules 1-6"` — stale since tasks 1–2 added validation rules #7 and #8 (tier hint enums) to `plan-format.md`.

**Fixed:** Changed `rules 1-6` → `rules 1-8`.

Post-fix verification: grep returns empty (no stale ranges remain).

All other rule-range references checked:
- `updating-dag-plans/SKILL.md:25,81` — H1-H9, S1-S9: correct.
- `plan-quality.md:76,77` — H1-H9, S1-S9: correct.
- `writing-dag-plans/SKILL.md:54,174,175` — H1-H9, S1-S9: correct.

### Step 4: Non-goal guard

Command: `grep -n "^model:" agents/*.md`

**Result:**
```
agents/dag-implementer.md:4:model: sonnet
agents/dag-quality-reviewer.md:4:model: sonnet
agents/dag-spec-reviewer.md:4:model: sonnet
```

**Verdict: CONFIRMED — all three agents declare `model: sonnet`. Not touched.**

---

## Part B — Accumulated Minor Findings

### B.1 — plan-format.md §Tier resolution: imprecise asymmetry description

**Real?** YES. Line 121 read: `"The naming asymmetry (no _hint suffix on the per-task field) is explicit and intentional."` — this is factually wrong because the per-task implementer field IS `model_hint` (it has `_hint`). The real asymmetry is that the role name is `model` (not `model_hint`), but the field is `model_hint`, which does share the `_hint` pattern with `spec_reviewer_hint` and `quality_reviewer_hint`.

**Fixed.** Rewrote line 121 to:
> `- `model` — the implementer. Per-task field: `model_hint`. Plan-level default: `default_model_hint`. The resolver evaluates `task["model" + "_hint"]` = `task["model_hint"]` — the asymmetry is that the role name is `model` while the reviewer roles are `spec_reviewer` / `quality_reviewer`, but all three per-task fields end in `_hint` (`model_hint`, `spec_reviewer_hint`, `quality_reviewer_hint`). This is explicit and intentional.`

### B.2 — executing-dag-plans/SKILL.md: BLOCKED table missing `opus` ceiling

**Real?** YES. The BLOCKED row read: `"cheap→standard, standard→opus"` — no mention of what happens when the original tier is already `opus`. The implementer-prompt.md template (line 123) does correctly list `opus → (no retry — go straight to failed)`, but the SKILL.md status table was silent.

**Fixed.** Changed the BLOCKED row to:
> `Auto-retry-once with bumped model: (cheap→standard, standard→opus; an already-opus tier stays at opus — there is no tier above it). On second BLOCKED, mark task failed.`

### B.3 — executing-dag-plans/SKILL.md: pre-flight halt message names field+value but not task id

**Real?** YES. Line 35 read: `"Halt with a clear error naming the offending field + value if any fails"` — omits the task id, which the Global Constraint requires ("refuse/halt naming the offending task id + field").

**Fixed.** Changed to:
> `Halt with a clear error naming the offending task id (or plan-level for a default_*_hint field), field name, and bad value if any fails`

### B.4 — updating-dag-plans/SKILL.md: trailing `|` on new tier-hint rows

**Real?** NO. Checked lines 54–55. Both new rows (`Modify tier hint` and `Modify plan-level default hint`) have a trailing `|` consistent with all other rows in the table. No fix needed.

---

## Part C — Behavioral Checklist (reasoning verification, no edits)

### C.1: A plan with no hints resolves all roles to `standard` = today

`resolve_tier(task, role)` checks `task[role+"_hint"]` (absent), then `plan_frontmatter["default_"+role+"_hint"]` (absent), then returns `"standard"`. `resolve_model("standard")` = `"sonnet"`. Three roles × same logic = three `sonnet` dispatches. **Consistent with "no-migration" claim.**

### C.2: `model_hint: cheap` → haiku first, BLOCKED→sonnet, second BLOCKED→failed

- First dispatch: `resolve_tier(task, "model")` = `"cheap"` (per-task hint present); `resolve_model("cheap")` = `"haiku"`.
- BLOCKED: retry ladder bumps one tier: cheap→standard. `resolve_model("standard")` = `"sonnet"`.
- Second BLOCKED: SKILL.md says "On second BLOCKED, mark task `failed`". Confirmed by both the status table (B.2 fix) and implementer-prompt.md line 123 (`opus → no retry — go straight to failed` equivalently applies to the second-BLOCKED path). **Consistent.**

### C.3: review-issue re-dispatch stays at original resolved tier (not BLOCKED-upgraded)

SKILL.md line 53: `"Review-issue re-dispatch of the implementer uses the original resolved implementer tier (NOT the BLOCKED-upgraded one) — only BLOCKED upgrades."` Implementer-prompt.md §Re-dispatch on review issues: `"Review-issue re-dispatch uses the original resolved tier, not the BLOCKED-upgraded one."` **Consistent across both files.**

### C.4: `model_hint` mutation accepted on pending/ready, refused on running

`updating-dag-plans/SKILL.md` operations table: `"Modify tier hint"` row has pre-condition `"Target's status is pending or ready"`. Hard invariant: `running` ∈ {immutable} → refused. Example refusal at line 126 explicitly shows `"Cannot modify task-3.model_hint (status: running)"`. **Consistent.**

---

## Files Changed

| File | Change |
|---|---|
| `skills/writing-dag-plans/SKILL.md` | Part A Step 3: `rules 1-6` → `rules 1-8` |
| `skills/writing-dag-plans/plan-format.md` | Part B.1: rewrote asymmetry description for `model` role |
| `skills/executing-dag-plans/SKILL.md` | Part B.2: BLOCKED table — added `opus` ceiling note |
| `skills/executing-dag-plans/SKILL.md` | Part B.3: pre-flight halt — names task id + field + value (not just field + value) |

## Fix: step-6 bullets

Added missing rules #7 and #8 to the step-6 validation bullet list in `skills/writing-dag-plans/SKILL.md`. The list now has 8 bullets:
- Unique ids.
- No cycles (DFS-based check).
- All `depends_on:` references resolve to existing task ids.
- Required fields present per task.
- File-disjoint parallel branches.
- Immutable history (only relevant for updates — N/A for fresh authoring).
- Per-task hint enum: `model_hint`, `spec_reviewer_hint`, `quality_reviewer_hint` must be `cheap | standard | opus` when present.
- Plan-level default enum: `default_model_hint`, `default_spec_reviewer_hint`, `default_quality_reviewer_hint` must be `cheap | standard | opus` when present.

These rules are defined in `plan-format.md` §Validation rules (lines 213–214) and are now reflected in the step-6 procedure. No changes to plan-format.md itself; SKILL.md step 6 now correctly enumerates all rules.

---

## Concerns

None. All Part B items were verified as real (except B.4 which was confirmed already correct). All four fixes are targeted, additive, and do not change execution semantics. The Global Constraint "no silent fallbacks" is now more precisely enforced in the pre-flight description.

---

## Final-review fixes

Three minor fixes applied in one commit from the whole-branch final review:

| Fix | File | Change |
|---|---|---|
| Fix 1 (correctness) | `skills/executing-dag-plans/implementer-prompt.md` | BLOCKED-retry table left-column header changed from `Original \`model_hint\`` to `Resolved implementer tier`; `standard (default)` row label changed to `standard` — table now keys on the resolved tier, not the absent per-task field. |
| Fix 2 (fixture clarity) | `tests/fixtures/tiers/should-warn/s9-multi-system-wiring.md` | Wiring task title renamed from `"wire api, ui, and jobs"` to `"wire three subsystems together"` in both the `## Task:` heading and the mermaid node label — removes the list-with-"and" that sat on the H1 boundary while keeping `id`, `files:`, `depends_on:`, `is_wiring_task: true`, and EXPECTED comment untouched. |
| Fix 3 (future-proofing) | `skills/writing-dag-plans/plan-quality.md` | Added one sentence to the S9 row noting that S9 Pattern 2's per-task novelty regex is deliberately different from `writing-dag-plans` SKILL step 6.6's plan-level aggregate regex — they are not duplicates and should not be reconciled. |
