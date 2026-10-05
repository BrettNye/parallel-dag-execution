ISSUES

1. Requirement: Step 1 says "Semantic content unchanged" and the output spec is the APPROVED / ISSUES format. | Actual: The ISSUES line in the template now ends with `| Severity: LOW/MEDIUM/HIGH". Rate severity by how far the implementation diverges from the spec.` Neither the original template nor the spec has this. | Fix: Remove the Severity field and the severity-rating sentence. Restore the original line: `**ISSUES** — list each as: "Requirement: ... | Actual: ... | Fix: ...". Be specific enough that the implementer can act without asking clarifying questions.`

2. Requirement: Step 3 verification. `grep -nE "...|Stable preamble"` must match the reordered preamble. | Actual: The grep matches only the Agent example (line 72). The preamble is labelled lowercase "(1) stable preamble" in an HTML comment, so "Stable preamble" does not match. | Fix: Add a visible "Stable preamble" label (for example, capitalised in the ordering comment or as a heading or marker) so the grep matches it.

3. Requirement: The order includes "(2) project conventions if any". | Actual: The template has no project-conventions section or placeholder. The ordering comment only mentions it. | Fix: Add an optional project-conventions placeholder, for example `{project conventions, if any}`, between the preamble and the Output section. This is a minor under-build.

4. Possible over-build: The ordering comment includes an extra sentence about a future `cache_control` breakpoint after section 3. The spec does not ask for it. | Fix: Remove that sentence, unless Task 6 has the same comment and you are mirroring it.

The following are met. The sections are reordered as preamble, output, task spec, body, implementation, then the re-dispatch section. The literal Agent invocation matches the spec. The "spec compliance only — no style" instruction is preserved.

File: /home/user/parallel-dag-execution/skills/executing-dag-plans/spec-reviewer-prompt.md
