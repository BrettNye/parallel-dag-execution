**ISSUES**

1. Requirement: Step 1 says "Semantic content unchanged", and the ISSUES format must stay `"Requirement: ... | Actual: ... | Fix: ..."`. | Actual: the ISSUES line in the template's Output section now adds `| Severity: LOW/MEDIUM/HIGH` and the sentence "Rate severity by how far the implementation diverges from the spec." Nothing in Task 7 asks for this, so it is over-build and changes the output contract. | Fix: Restore the original line: `**ISSUES** — list each as: "Requirement: ... | Actual: ... | Fix: ...". Be specific enough that the implementer can act without asking clarifying questions.`

2. Requirement: Step 3 expects grep to match "Stable preamble" for the reordered preamble. | Actual: the only occurrence is lowercase, "(1) stable preamble", in the HTML comment. The case-sensitive grep `"Stable preamble"` therefore does not match it. The Agent-example half of the grep does match. | Fix: Capitalize it, for example "(1) Stable preamble", so both grep alternatives match.

Everything else is met:
- The section order matches the spec.
- The literal Agent example is present and correct.
- The APPROVED/ISSUES output and the "spec compliance only, no style" instruction are preserved.

File: /home/user/parallel-dag-execution/skills/executing-dag-plans/spec-reviewer-prompt.md
