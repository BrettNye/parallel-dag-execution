**ISSUES**

Steps 1 and 2 are met. Step 3 is only partly done at commit a2d482e.

- **Requirement (Step 3, reviewer dispatch):** After the chain diagram, state that the spec reviewer is dispatched with `model: resolve_model(resolve_tier(task, 'spec_reviewer'))` and the quality reviewer with `model: resolve_model(resolve_tier(task, 'quality_reviewer'))`. Also state that "Reviewer tiers fall back per-task → plan-level default → `standard`."
  - **Actual:** The commit added only the sentence "Review-issue re-dispatch of the implementer uses the original resolved implementer tier (NOT the BLOCKED-upgraded one) — only BLOCKED upgrades." The file at that commit has no `spec_reviewer` or `quality_reviewer` reference at all, and no reviewer fallback statement.
  - **Fix:** Add the missing reviewer sentences to `/home/user/parallel-dag-execution/skills/executing-dag-plans/SKILL.md` after the chain diagram, in the spec's wording. This also makes the Step 4 grep match the two reviewer sites (`spec_reviewer')` and `quality_reviewer')`).

- **Working-tree note:** The current working tree at HEAD does contain these reviewer resolve calls and the fallback sentence. A later commit added them, not a2d482e. The task's commit did not deliver them. If later commits are acceptable to you, this issue is moot.

**Steps 1 and 2:** The implementer dispatch passes `model: resolve_model(resolve_tier(task, 'model'))`. It states the `model_hint` → `default_model_hint` → `standard` fallback. It says BLOCKED-retry still bumps one tier above the resolved tier. The pre-flight sentence validates `*_hint` and `default_*_hint` against `{cheap, standard, opus}`, halts naming the field and value, and has no silent fallback.

**Over-build:** None found.
