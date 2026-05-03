# Implementer dispatch template

This is the prompt template for dispatching an implementer subagent on one DAG-plan task. The executor (controller) constructs this prompt per task and invokes the agent via the Agent tool with `subagent_type: <task.implementer or dag-implementer>` — see `../writing-dag-plans/plan-format.md` §Per-task frontmatter schema for the `implementer:` field.

The template body below is persona-agnostic. The selected subagent's own system prompt provides the persona (TDD discipline, file-scope respect, channel/journal etiquette). This template only supplies task-specific context.

## Context construction rules

The implementer must NOT receive:

- The full plan file.
- Other tasks' bodies.
- The DAG visualization.
- Conversation history from the controller.

The implementer MUST receive:

- This task's full body (everything after the YAML block, up to the next `## Task` heading).
- This task's frontmatter (id, depends_on, files).
- An "upstream context" block: for each task id in `depends_on:`, a short summary of what that upstream task produced — paths created/modified, key types/contracts/exports, commit SHA. Pull these from the plan file's task body for `done` upstream tasks.
- The repo's `CLAUDE.md` (if present) so it follows project conventions.

## Prompt template

```
You are dispatched to implement one task in a DAG-aware execution plan.

## Task spec

ID: {task.id}
Files (you may modify ONLY these):
{for each path in task.files: "  - " + path}

depends_on: {task.depends_on or "[] (root task)"}

### Body

{task.body}

## Upstream context (what the tasks you depend on produced)

{for each upstream_id in task.depends_on:}
### {upstream_id}: {upstream.title}
- Files modified: {upstream.files}
- Commit: {upstream.commit_sha}
- Summary: {one-paragraph synthesis from upstream task body — what was implemented, what to know about its contracts}

{if no upstream: omit this section entirely}

## Project conventions

{contents of repo's CLAUDE.md, if any}

## Your output

Implement the task per your agent system prompt. Use TDD. Commit when green. Report:

- DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
- Commit SHA (for DONE / DONE_WITH_CONCERNS)
- One-line summary of what was implemented (for DONE / DONE_WITH_CONCERNS)
- Concerns / questions / blocker explanation (for the other statuses)

Modify ONLY the files in your task's `files:` list. If you discover you need another file, STOP and report BLOCKED.
```

## Re-dispatch on review issues

When the spec or quality reviewer reports ISSUES, re-dispatch the implementer with the same task context PLUS the issue list:

```
You previously implemented {task.id} but the {spec / quality} reviewer found issues. Address them and re-commit.

## Issues to fix

{reviewer's issue list, verbatim}

## Constraints

- Do NOT change anything that the reviewer didn't flag.
- Stay within your task's `files:` list.
- Re-run tests after fixes.
- Commit a fixup commit (do not amend the previous commit unless explicitly directed).

Report DONE / BLOCKED as before.
```

## Re-dispatch on BLOCKED with model upgrade

When the implementer reports BLOCKED, re-dispatch ONCE with a more capable model:

| Original `model_hint` | Retry model |
|---|---|
| `cheap` | `standard` (sonnet) |
| `standard` (default) | `opus` |
| `opus` | (no retry — go straight to `failed`) |

The retry prompt includes the original BLOCKED report so the next-tier model can see what stuck the first attempt:

```
Previous attempt by a {original-tier} model reported BLOCKED:

{original BLOCKED explanation}

Re-attempt the same task with fresh eyes. The previous attempt's blocker may indicate a real impossibility OR a need for more reasoning capacity — try to discriminate. If you also conclude BLOCKED, the task will be marked failed and the executor will halt this branch's downstream.

[Original task spec follows...]
```
