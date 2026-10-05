ISSUES

1. Requirement: Step 1 says "Semantic content unchanged" and the output spec is "APPROVED / ISSUES format". The original ISSUES format was `"Requirement: ... | Actual: ... | Fix: ..."`. | Actual: the implementation added `| Severity: LOW/MEDIUM/HIGH` and the sentence "Rate severity by how far the implementation diverges from the spec." in the Output section (about line 45 of spec-reviewer-prompt.md). This is over-build and a semantic change. | Fix: remove the `| Severity: LOW/MEDIUM/HIGH` field and the severity-rating sentence. Restore the original line: `**ISSUES** — list each as: "Requirement: ... | Actual: ... | Fix: ...". Be specific enough that the implementer can act without asking clarifying questions.`

2. Requirement: Step 3 expects `grep -nE "resolve_tier\(task, \"spec_reviewer\"\)|Stable preamble"` to match both the Agent example and the reordered preamble. | Actual: the grep matches only the Agent example (line 72). The ordering comment says lowercase "stable preamble", so "Stable preamble" does not match. | Fix: capitalize it in the ordering comment (e.g. "(1) Stable preamble; ..."), or add a "Stable preamble" label, so the grep matches both.

3. Minor over-build: the ordering comment adds a note about a future `cache_control` breakpoint after section 3. The spec does not ask for it. | Fix: remove that sentence, unless the Task 6 equivalent has it and the plan intends parity.

Everything else is met:
- The template order is preamble, output spec, task spec, task body, implementation under review.
- The "spec compliance only — no style" instruction and the APPROVED/ISSUES output spec are preserved.
- The Agent invocation matches the spec exactly.
