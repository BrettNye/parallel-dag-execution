ISSUES

1. Requirement: Step 3 verify command `grep -nE "resolve_tier\(task, \"spec_reviewer\"\)|Stable preamble"` must match both the Agent example and the reordered preamble. | Actual: it matches only line 72, the Agent example. The only preamble marker is lowercase "stable preamble" inside the HTML comment on line 23, so the "Stable preamble" half of the expected check fails. | Fix: in /home/user/parallel-dag-execution/skills/executing-dag-plans/spec-reviewer-prompt.md, add a capitalized "Stable preamble" marker that matches the grep. For example, change the comment to "(1) Stable preamble" or label the preamble section that way.

2. Requirement: Step 1 lists "(2) project conventions if any" as a section in the reordered template. | Actual: project conventions appear only in the HTML comment on line 23. The template body has no project-conventions slot or placeholder between the preamble and the output spec. | Fix: add an optional "Project conventions (if any)" placeholder in the template body after the preamble and before "## Output". Alternatively, confirm this was deliberately omitted because the original template had no such section.

Everything else is met.
- The reorder is correct: preamble, output spec, task spec, task body, implementation under review.
- The APPROVED/ISSUES output format and the "spec compliance only, no style" instruction are preserved.
- The Agent invocation example matches the spec literally.
- The re-dispatch addenda section still follows the template.
