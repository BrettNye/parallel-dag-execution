ISSUES

1. Requirement: Semantic content unchanged (Step 1) | Actual: The ISSUES output format gained new text, `| Severity: LOW/MEDIUM/HIGH". Rate severity by how far the implementation diverges from the spec.` The original format was "Requirement | Actual | Fix". | Fix: Remove the Severity field and the severity sentence from the ISSUES line in the template. Restore the original wording.

2. Requirement: Step 3 grep expects a match for "Stable preamble" (reordered preamble). | Actual: grep -nE "resolve_tier\(task, \"spec_reviewer\"\)|Stable preamble" matches only the Agent example (line 72). The comment on line 23 says lowercase "stable preamble", so the preamble match is missing. | Fix: Make the text literally contain "Stable preamble", for example "(1) Stable preamble" in the ordering comment or as a label above the preamble in the template.

3. Requirement: Section order includes (2) project conventions if any. | Actual: The template has no project-conventions placeholder or section. It is mentioned only in the HTML comment. | Fix: Add an optional project-conventions slot between the preamble and the Output section, marked "if any". Alternatively, confirm the original template had no such slot and document that.

4. Over-build (minor): The comment says "If the Agent tool later exposes `cache_control`, the breakpoint goes after section 3". The spec does not ask for this. | Fix: Remove that sentence.

Requirements met:
- Preamble, then output, then task spec, then task body, then implementation order.
- Literal Agent example is correct.
- APPROVED/ISSUES output and the "spec compliance only" instruction are preserved.
