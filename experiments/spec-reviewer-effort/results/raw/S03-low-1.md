ISSUES

1. Requirement: Step 3 says to add, after the chain diagram, a sentence that dispatches the spec reviewer with `model: resolve_model(resolve_tier(task, 'spec_reviewer'))` and the quality reviewer with `model: resolve_model(resolve_tier(task, 'quality_reviewer'))`. It must also say that reviewer tiers fall back per-task -> plan-level default -> `standard`.
   Actual: The diff adds only the sentence about implementer re-dispatch after review issues ("Review-issue re-dispatch of the **implementer** uses the original resolved implementer tier..."). Neither reviewer dispatch is resolved, and there is no reviewer fallback statement.
   Fix: In /home/user/parallel-dag-execution/skills/executing-dag-plans/SKILL.md, after the chain diagram and next to the existing re-dispatch sentence, add: "Dispatch the spec reviewer with `model: resolve_model(resolve_tier(task, 'spec_reviewer'))` and the quality reviewer with `model: resolve_model(resolve_tier(task, 'quality_reviewer'))`. Reviewer tiers fall back per-task -> plan-level default -> `standard`."
   Because of this gap, the Step 4 grep would not match at the two reviewer sites.

2. Requirement: Step 1 says only that the BLOCKED-retry ladder "still bumps one tier above the resolved tier (unchanged)".
   Actual: The commit adds an extra clause, "(cheap->standard, standard->opus)", and the sentence "the BLOCKED upgrade is one step above the original resolved tier, not a fixed override."
   Fix: This is minor over-build. Trim it to the plain note, unless the existing ladder text already states the mapping.

Steps 1 and 2 (the implementer `model:` resolution and the pre-flight `*_hint` validation) are otherwise met.
