# dag-merged-reviewer dispatch template

This is the prompt template for dispatching the `dag-merged-reviewer` subagent when a task resolves to `review_mode: merged` (see `../writing-dag-plans/plan-format.md` §Review-mode resolution). It fuses the spec-reviewer and quality-reviewer templates into one pass returning both verdicts.

## Context construction rules

The merged reviewer must NOT receive: other tasks' content, the full plan file, conversation history.
The merged reviewer MUST receive: this task's body, its `files:` list, the git commit SHA produced by the implementer.

## Prompt template

<!-- Section order (cache-friendly: stable content leads, volatile content trails):
     (1) stable preamble; (2) project conventions (if any); (3) output spec (BOTH verdicts);
     (4) task spec (id, files); (5) task body; (6) implementation under review; (7) re-dispatch addenda.
     If the Agent tool later exposes `cache_control`, the breakpoint goes after section 3 — no re-architecture needed. -->

```
You are dispatched to review one DAG-plan task in a single pass: BOTH whether it matches its spec AND whether it is well-built. This merged review replaces the separate spec and quality reviews for this (small/mechanical) task.

Use `superpowers:requesting-code-review` (auto-loaded for you via the `skills:` frontmatter field) for the quality half.

## Output

Report TWO verdicts; the task passes only if BOTH are APPROVED.

### Spec compliance (bidirectional)
- **APPROVED** — all requirements met, no over-build.
- **ISSUES** — list each as: "Requirement: ... | Actual: ... | Fix: ...".
Under-build (spec requires X, impl lacks X) and over-build (spec doesn't ask for Y, impl includes Y) are equally serious. Acceptance criteria in the task body ARE the spec.

### Code quality
- **APPROVED** — quality solid; suggestion-severity issues do NOT block, flag but APPROVE.
- **ISSUES** — list each as: "Severity: Important | Location: file:line | Issue: ... | Fix: ...".
Focus: correctness (subtle bugs, edge cases), clarity (names, intent), maintainability (magic numbers, hidden coupling), test quality (verify behavior not mocks).

## Task spec (binding for spec compliance; context for quality)

ID: {task.id}
Files reviewed (read ONLY these):
{for each path in task.files: "  - " + path}

### Body

{task.body}

## Implementation under review

Commit SHA: {commit_sha}

Inspect the diff with: `git show {commit_sha} -- {space-separated task.files}`
```

## Agent invocation example

The controller LLM dispatches each merged review using the Agent tool. A merged review uses the `quality_reviewer` tier (it does both jobs):

```javascript
Agent({
  description: "Merged-review task-3",
  subagent_type: "dag-merged-reviewer",
  model: resolve_model(resolve_tier(task, "quality_reviewer")),
  prompt: <constructed-from-template-above>
})
```

## Re-dispatch on implementer fix

When EITHER verdict reports ISSUES, the implementer fixes them and re-commits; re-dispatch the merged reviewer with the new commit SHA. Fresh review on the new diff.

## Approval criteria

- Spec: every requirement implemented, no over-build, tests cover requirements.
- Quality: no correctness bugs, no Important-severity issues open, tests verify behavior, no surprising coupling.

Once the merged reviewer reports BOTH verdicts APPROVED, the executor marks the task `done`, regenerates the mermaid block, re-renders the ASCII tree, and recomputes the `ready` set.
