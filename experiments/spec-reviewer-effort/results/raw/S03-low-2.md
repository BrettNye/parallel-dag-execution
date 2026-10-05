APPROVED. Commit a2d482ef touches only skills/executing-dag-plans/SKILL.md and meets every step of Task 5 with no over-build. I read the diff and did not run the Step 4 grep.

- **Step 1, implementer dispatch (step 4):** met. It adds `model: resolve_model(resolve_tier(task, 'model'))`, the pointer to plan-format.md §Tier resolution, and the `model_hint` → `default_model_hint` → `standard` fallback. It also states that the BLOCKED-retry ladder bumps one tier above the resolved tier.
- **Step 2, pre-flight:** met. The new sentence validates every `*_hint` and `default_*_hint` against {cheap, standard, opus}, halts naming the offending field and value, and says there is no silent fallback to standard.
- **Step 3, reviewer dispatch:** partially met. The diff adds the line that the review-issue re-dispatch of the implementer uses the original resolved tier and only BLOCKED upgrades. It does not add the spec-reviewer and quality-reviewer `model: resolve_model(resolve_tier(task, 'spec_reviewer'))` / `'quality_reviewer'` sentence or the per-task → plan-level default → `standard` fallback for reviewers. The Step 4 grep expects matches at both reviewer sites.

Fix: add a sentence to §Per-task review chain after the diagram, using the Step 3 wording, covering the spec-reviewer and quality-reviewer dispatches and their fallback chain.
