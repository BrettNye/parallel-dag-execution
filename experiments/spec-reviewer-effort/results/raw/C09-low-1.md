ISSUES

Requirement: Step 3 verify grep `grep -nE "resolve_tier\(task, \"spec_reviewer\"\)|Stable preamble"` should match both the Agent example and the reordered preamble. | Actual: it matches only line 72, the Agent example. The ordering comment at line 23 says lowercase "(1) stable preamble", and the grep is case-sensitive, so the preamble is not matched. | Fix: label the preamble with the capitalized text "Stable preamble", for example in the ordering comment "(1) Stable preamble; ...". Alternatively, add a "Stable preamble" marker to the template.

The following requirements are met:
- Section order is preamble, output spec, task spec, task body, implementation under review.
- APPROVED/ISSUES output and the "spec compliance only, no style" instruction are preserved.
- The Agent invocation matches the spec literally.

Other points:
- Section (2), project conventions, is only named in the ordering comment. The template has no conventions placeholder. This is likely acceptable because the spec says "if any", but note it.
- Section (7), re-dispatch addenda, is likewise only named in the comment. It is not in the template.
- The commit added an HTML comment about a possible `cache_control` breakpoint, which the spec does not ask for. It is minor over-build.

File: /home/user/parallel-dag-execution/skills/executing-dag-plans/spec-reviewer-prompt.md
