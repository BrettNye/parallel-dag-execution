APPROVED. Reviewed commit 4bf49ef0b9732f43421627316fa7e4d616cd7a06, which touches only skills/executing-dag-plans/SKILL.md.

- **Step 1, review chain branch:** met. §Per-task review chain now branches on `resolve_review_mode(task)` and cites the resolver in `../writing-dag-plans/plan-format.md`. The `split` and `merged` diagrams and the closing paragraph match the spec text.
- **Split path:** behavior unchanged. The stages and loops are the same. The only change is that the model expressions moved from the old tier sentence into the diagram annotations. The spec calls for this.
- **Merged path:** dispatches `dag-merged-reviewer` at the quality_reviewer tier. It needs BOTH verdicts APPROVED to mark the task `done`. If either verdict is ISSUES, it re-dispatches the implementer with the combined feedback, then runs the merged re-review and loops.
- **Step 2, pre-flight:** met. The text appended to step 4 validates `review_mode` and `default_review_mode` against `{merged, split}`, with no silent fallback. It requires `dag-merged-reviewer` in the registry when any task resolves to `merged`, and halts with the deploy-the-agent message if it is missing.
- **Over-build:** none. The diff contains no changes beyond what the spec asks for.
