ISSUES

Requirement: Step 1 says to change only "S1-S6" to "S1-S9" in the plan-quality.md bullet. Nothing else in that bullet is in scope.
Actual: The commit also changed "hard rules (H1-H6" to "H1-H9" in /home/user/parallel-dag-execution/skills/writing-dag-plans/SKILL.md. This is an unrequested edit, so it is over-build. The value is consistent with step 7, which already says H1-H9.
Fix: Revert that bullet to "H1-H6" and keep only the S1-S6 to S1-S9 change. If H1-H9 is the intended value, that correction belongs in a separate task.

Everything else matches the spec:
- Step 1: The plan-format.md bullet now lists the new per-task fields (spec_reviewer_hint, quality_reviewer_hint), the plan-level defaults (default_model_hint, default_spec_reviewer_hint, default_quality_reviewer_hint) and §Tier resolution.
- Step 2: Step 6.6 sits between step 6.5 and step 7. It has the mechanical and novelty signal regexes and file globs, the mechanical_pct and novelty_pct calculations, and the >70% and <10% prompt with the exact wording. It also states that plan-level defaults are never auto-written and that there is no per-task prompting.
- Step 3: Step 7 now says S1-S9. It also adds a parenthetical name for S9, "tier-complexity mismatch", which I consider harmless.

I did not run the Step 4 grep.
