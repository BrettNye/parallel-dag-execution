# dag-spec-reviewer dispatch template

This is the prompt template for dispatching the `dag-spec-reviewer` subagent after an implementer reports DONE on a task. The reviewer's job is bidirectional spec compliance — catches both under-build (missing requirements) and over-build (extra unrequested features).

## Context construction rules

The spec reviewer must NOT receive:

- Other tasks' specs.
- The full plan file.
- Style/quality guidance (that is the next reviewer's job).
- Information about prior implementations or previous review iterations.

The spec reviewer MUST receive:

- This task's full body (everything after the YAML block, up to the next `## Task` heading).
- This task's `files:` list.
- The git commit SHA that the implementer produced.

## Prompt template

<!-- Section order (cache-friendly: stable content leads, volatile content trails):
     (1) stable preamble; (2) project conventions (if any); (3) output spec (APPROVED/ISSUES);
     (4) task spec (id, files); (5) task body (the binding spec);
     (6) implementation under review; (7) re-dispatch addenda.
     If the Agent tool later exposes `cache_control`, the breakpoint goes after section 3 — no re-architecture needed. -->

```
You are dispatched to review one DAG-plan task implementation against its spec.

Your job is bidirectional spec compliance:

- **Under-build:** spec requires X, implementation lacks X.
- **Over-build:** spec doesn't ask for Y, implementation includes Y.

Both are equally serious. Acceptance criteria in the task body ARE the spec.

Do NOT comment on code style, naming, performance, or maintainability — that is the quality reviewer's job. Spec compliance only.

## Output

Report exactly one of:

- **APPROVED** — all requirements met, no over-build.
- **ISSUES** — list each as: "Requirement: ... | Actual: ... | Fix: ...". Be specific enough that the implementer can act without asking clarifying questions.

## Task spec (binding)

ID: {task.id}
Files reviewed (read ONLY these):
{for each path in task.files: "  - " + path}

### Body (the spec)

{task.body}

## Implementation under review

Commit SHA: {commit_sha}

Inspect the diff with: `git show {commit_sha} -- {space-separated task.files}`
```

## Agent invocation example

The controller LLM dispatches each spec review using the Agent tool. Include `model:` at dispatch so the resolved tier is honoured:

```javascript
Agent({
  description: "Spec-review task-3",
  subagent_type: "dag-spec-reviewer",
  model: resolve_model(resolve_tier(task, "spec_reviewer")),
  prompt: <constructed-from-template-above>
})
```

## Re-dispatch on implementer fix

After the implementer addresses ISSUES and re-commits, dispatch the spec reviewer again with the new commit SHA. The reviewer should not see prior iteration history — fresh review against the same spec on the new diff.

## Approval criteria

- Every requirement explicitly listed in the task body is implemented.
- Acceptance criteria pass.
- No additions outside what was requested (refactoring unrelated code, adding extra flags, "while I was here" changes).
- Tests cover the requirements (presence, not necessarily quality — that's the next reviewer).

Once the spec reviewer reports APPROVED, the executor proceeds to the quality reviewer.
