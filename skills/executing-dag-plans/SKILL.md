---
name: executing-dag-plans
description: Use when you have a DAG plan authored by `writing-dag-plans` and want to execute it with continuous parallel subagent dispatch. Maintains a ready queue, dispatches multiple implementer subagents per tick, runs spec+quality review per task, auto-retries-once on BLOCKED with model upgrade, and halts only the failed branch's downstream lineage on hard failure (parallel branches keep going). Resumable — re-invoke on a partially-executed plan to pick up where it left off.
---

# Executing DAG Plans

Run a DAG plan with continuous parallel subagent dispatch. Where `superpowers:subagent-driven-development` runs one task at a time, this skill saturates the ready queue with concurrent implementer subagents while respecting `depends_on` and `files:` scope.

## When to use

- A plan file authored by `writing-dag-plans` exists.
- You want parallel execution along the dependency graph.
- You can dispatch subagents (Claude Code controller environment).

## When NOT to use

- Plan format isn't DAG-aware → use `superpowers:subagent-driven-development` instead.
- All tasks are tightly coupled / sequential → no parallelism gain; use `superpowers:executing-plans` or `subagent-driven-development`.

## Required reading before executing

- `../writing-dag-plans/plan-format.md` — the format you're consuming.
- `./implementer-prompt.md`, `./spec-reviewer-prompt.md`, `./quality-reviewer-prompt.md` — the subagent dispatch templates.

## Execution model

The executor is a **synchronous controller-turn loop**, not a background process. Each "tick" is one turn of the controller LLM. Within a tick:

1. Read the plan file (fresh — picks up any `/update` mutations applied between ticks).
2. Topo-sort. Compute `ready` set: tasks with all `depends_on:` in `done` and current status `pending` or `ready`.
3. Promote those tasks from `pending` to `ready` in the plan file.
4. **Dispatch in parallel:** for each ready task, verify file-scope tripwire (no overlap with currently `running` tasks), then dispatch a fresh implementer subagent via the Agent tool. The dispatched `subagent_type` is the task's `implementer:` field, defaulting to `dag-implementer` when absent (see `../writing-dag-plans/plan-format.md` §Per-task frontmatter schema). Mark task `running`. **All ready tasks dispatch in the same tick — that's the parallelism.**

   When constructing each implementer dispatch, substitute the absolute path to `skills/executing-dag-plans/git-commit-safe` into the prompt's `{git_commit_safe_path}` placeholder (resolve it from the plugin root). Implementers commit through this helper so concurrent dispatches in the same tick never race on the shared git index.

   Pre-flight check: before the first dispatch tick, verify every distinct `implementer:` value referenced by the plan resolves in the current harness's agent registry. If any are missing, halt with a clear error naming the missing subagent_type(s) and instruct the user to deploy them (`vault.sync-agents`) and `/clear` so the harness reloads. Newly-deployed `.claude/agents/*.md` files only register at session start in Claude Code today.
5. Continue per-task review chains (one per running task — they progress in parallel across the DAG).
6. As tasks reach terminal states (`done` / `failed`), update plan file frontmatter and re-render visualization.
7. Tick ends. The controller awaits next user prompt; the user can `/update` or just say "continue."

## Per-task review chain

Once an implementer reports DONE on a task:

```
implementer DONE
  → dispatch dag-spec-reviewer
      → APPROVED → dispatch dag-quality-reviewer
          → APPROVED → mark task `done`, persist status
          → ISSUES → re-dispatch implementer with quality feedback → loop
      → ISSUES → re-dispatch implementer with spec feedback → loop
```

Spec review precedes quality review — fixing spec compliance often changes the code being quality-reviewed.

## Implementer status handling

| Status | Action |
|---|---|
| **DONE** | Proceed to spec review. |
| **DONE_WITH_CONCERNS** | Read concerns. If correctness/scope, address before review. If observations only, log and proceed. |
| **NEEDS_CONTEXT** | Provide missing context, re-dispatch. |
| **BLOCKED** | Auto-retry-once with bumped `model:` (cheap→standard, standard→opus). On second BLOCKED, mark task `failed`. |

## Failure handling — D + B

When a task is marked `failed` (after auto-retry):

1. Walk transitive downstream of the failed task via the `depends_on:` graph.
2. Mark every task in that downstream set `skipped`.
3. Tasks NOT in the failed branch's downstream continue dispatching as their deps clear.
4. Run terminates when:
   - `ready` set is empty AND
   - No tasks are `running`.
5. Final report distinguishes: `<N> done`, `<F> failed`, `<S> skipped (downstream of failure)`.

The semantic is `make -k --keep-going`: extract maximum useful work from the DAG before halting.

## Visualization

Per the shared visualization contract (see `../writing-dag-plans/plan-format.md` §Mermaid block specification and §ASCII tree rendering):

- After each task's status transition (`ready` → `running`, `running` → `done`/`failed`), regenerate the mermaid block in the plan file. Status drives node coloring.
- After each tick, print the ASCII tree to the terminal with current status icons. This gives the user real-time progress without opening the plan file.

## Resumability

Because all task statuses live in the plan file's frontmatter, re-invoking `/parallel-dag-execution:execute` on a partially-executed plan picks up exactly where it left off:

- `pending` tasks await deps.
- `ready` tasks dispatch on the next tick.
- `running` tasks — if the controller was killed mid-tick, the implementer subagent's work was lost. Reset these to `ready` on resume so they re-dispatch. (The implementer commits per task, so partial work survives in git history; the rerun picks up from the last commit.)
- `done` / `failed` / `skipped` are immutable — never re-run.

## Hard rules

- NEVER dispatch two implementers whose `files:` lists overlap. The tripwire MUST fire if the planner missed a conflict — this is a hard halt with a clear error explaining which two tasks overlap on which file.
- NEVER mutate `running` / `done` / `failed` / `skipped` tasks via this skill — those statuses are managed by the dispatch loop only.
- NEVER dispatch the implementer subagent with the whole plan as context. Only the task's own text + immediate-deps context. Plan file is for the executor, not the workers.
- Persist plan file changes after every status transition. The plan file is the source of truth — if the controller dies, the plan file's status field is what survives.
- Do NOT skip either review stage. Spec compliance first, then code quality. No shortcuts.
- ALL implementer commits go through `git-commit-safe` (atomic-mutex + path-scoped commit). The dispatch MUST inject `{git_commit_safe_path}`. This is what prevents `index.lock` contention and cross-task stage-bundling when multiple implementers commit concurrently.

## Dispatch templates

See:
- `./implementer-prompt.md` for the `dag-implementer` dispatch.
- `./spec-reviewer-prompt.md` for the `dag-spec-reviewer` dispatch.
- `./quality-reviewer-prompt.md` for the `dag-quality-reviewer` dispatch.

These templates include the exact context construction logic — what to include from the plan, what to exclude, how to format the upstream-deps summary.
