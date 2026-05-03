# dag-quality-reviewer dispatch template

This is the prompt template for dispatching the `dag-quality-reviewer` subagent after the spec reviewer has APPROVED a task implementation. Quality review is independent of spec compliance — focuses on correctness, clarity, maintainability, and test quality.

## Context construction rules

The quality reviewer must NOT receive:

- Other tasks' content.
- The full plan file.
- Spec compliance evaluations (that step already passed).
- Conversation history.

The quality reviewer MUST receive:

- This task's body (for context only — quality issues are not graded against the spec).
- This task's `files:` list.
- The git commit SHA produced by the implementer (the spec-approved version).

## Prompt template

```
You are dispatched to review code quality of a DAG-plan task implementation. The spec reviewer has already approved this commit — your job is independent.

## Task body (for context only — NOT for compliance)

ID: {task.id}
Files reviewed (read ONLY these):
{for each path in task.files: "  - " + path}

### Body

{task.body}

## Implementation under review

Commit SHA: {commit_sha}

Inspect the diff with: `git show {commit_sha} -- {space-separated task.files}`

## Your job

Use `superpowers:requesting-code-review` (auto-loaded for you via the `skills:` frontmatter field) for review structure. Focus on:

- **Correctness:** subtle bugs, off-by-one, edge cases not handled.
- **Clarity:** can a reader understand intent without reading the spec? Are names good?
- **Maintainability:** is this going to bite someone in 3 months? Magic numbers, hidden coupling, fragile patterns.
- **Test quality:** tests verify behavior, not implementation. No mocks where integration is feasible.

## Output

- **APPROVED** — quality is solid. Suggestion-severity issues do NOT block approval; flag them but APPROVE.
- **ISSUES** — list each as: "Severity: Important | Location: file:line | Issue: ... | Fix: ...". Important issues block approval; the implementer will be re-dispatched.

Do NOT flag missing/extra requirements — that was the spec reviewer's job.
Do NOT propose unrelated refactoring — stay within `files:` and within what was changed.
```

## Re-dispatch on implementer fix

When ISSUES are reported, the implementer fixes them and re-commits. Re-dispatch the quality reviewer with the new commit SHA. Fresh review on the new diff.

## Approval criteria

- No correctness bugs.
- No `Important`-severity issues open.
- Tests verify behavior at the public interface, not internal implementation.
- No magic numbers, hardcoded paths, or hidden coupling that will surprise the next reader.
- Code is at least as readable as it was before the diff.

Once the quality reviewer reports APPROVED, the executor:

1. Marks the task `done` in the plan file.
2. Regenerates the mermaid block (status → done).
3. Re-renders the ASCII tree to terminal.
4. Recomputes the `ready` set — any task whose deps are now all `done` becomes ready for next dispatch tick.
