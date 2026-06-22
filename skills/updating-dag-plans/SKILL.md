---
name: updating-dag-plans
description: Use to mutate a DAG plan mid-flight — add tasks, remove tasks, modify task bodies or `files:` scope, or rewire `depends_on:` edges. Operates only on `pending` and `ready` tasks; refuses to touch `running`, `done`, `failed`, or `skipped` history. Pairs with `writing-dag-plans` (same validation rules) and `executing-dag-plans` (which reads fresh state on every tick, so updates between ticks are safe).
---

# Updating DAG Plans

Mutate an in-flight or partially-executed DAG plan without breaking resumability. Apply between executor ticks (the executor naturally pauses awaiting the next user prompt — there's no concurrency to manage).

## When to use

- An `executing-dag-plans` run is in progress (or has paused/failed) and you need to add, remove, or change a task.
- You realized a task's spec was wrong and want to fix it before the implementer dispatches.
- You discovered a missed dependency and want to add a `depends_on:` edge.
- You need to widen or narrow a task's `files:` scope.

## When NOT to use

- The plan hasn't been executed yet — just edit with `writing-dag-plans` (same validation, simpler entry point).
- You want to mutate `running` / `done` / `failed` / `skipped` tasks. **You can't.** History is immutable. Re-plan from scratch if the existing run produced incoherent state.

## Required reading

- `../writing-dag-plans/plan-format.md` — canonical *structural* contract and validation rules.
- `../writing-dag-plans/plan-quality.md` — canonical *decomposition-quality* contract (DRY, Single Responsibility, SoC, best-practice signals). Hard rules H1-H9 and soft heuristics S1-S9.

Updates that add new tasks or modify task bodies/scope must pass BOTH validations, same as fresh authoring.

## The hard invariant

```
Mutable: status in { pending, ready }
Immutable: status in { running, done, failed, skipped }
```

Updating a task in any of the four immutable statuses is **refused** — the skill explains why and exits without mutating the plan file. The reasoning:

- `running`: an implementer is mid-task. Changing its spec under it produces undefined behavior.
- `done`: the work shipped. Editing the spec retroactively desynchronizes plan from reality.
- `failed`: the failure cascade has already marked downstream `skipped`. Reverting the failure mid-cascade leaves an inconsistent state.
- `skipped`: same logic as failed — changing this requires undoing the cascade, which is what re-planning is for.

If the user genuinely needs to mutate immutable history, the answer is to author a new plan (or a follow-up plan) — not to corrupt the existing one.

## Operations supported

| Op | Pre-condition | Behavior |
|---|---|---|
| **Add task** | None | Prompt for `id`, `depends_on`, `files`, body. Validate per `plan-format.md`. Insert into `## Tasks` section. New task starts `status: pending`. Re-render mermaid + ASCII. |
| **Remove task** | Target's status is `pending`. No other non-`pending` task depends on it. | If other `pending` tasks depend on it, prompt user: rewire those deps to the target's parents, or refuse. Delete the task block. Re-render. |
| **Modify body** | Target's status is `pending` or `ready`. | Replace the task body (everything after the YAML block). No re-validation needed. Re-render only if body change affects mermaid label. |
| **Modify `files:`** | Target's status is `pending`. | Update the `files:` list in the YAML block. Re-run full file-scope conflict detection across the entire DAG. May surface new conflicts requiring additional `depends_on:` edges. |
| **Rewire `depends_on:`** | All affected tasks' statuses are `pending`. | Update `depends_on:` for the target. Re-run topo-sort + cycle detection + file-scope conflict detection. |
| **Modify tier hint** (`model_hint`, `spec_reviewer_hint`, `quality_reviewer_hint`) | Target's status is `pending` or `ready` | Update YAML field. Re-validate enum (`cheap | standard | opus`, rule #7). No mermaid re-render (label doesn't show tier). |
| **Modify plan-level default hint** (`default_*_hint` in frontmatter) | At least one task is `pending` or `ready` | Update frontmatter field. Re-validate enum (rule #8). Affects all tasks lacking a per-task override and not yet `running`/`done`/`failed`/`skipped`. Refuse if every task is already immutable. |

> **Why `ready` is mutable for tier hints:** Unlike `files:` (mutable only on `pending`, because a `ready` task queues for the next tick and a file-scope change could conflict with a running sibling), tier hints don't interact with the parallelism contract — mutating a `ready` task's tier between ticks is safe; the next tick reads fresh state and dispatches at the new resolved tier.

## Process

1. **Read the plan file.** Parse mermaid block (or skip — it'll be regenerated), all task YAML blocks and bodies.

2. **Determine the operation** from the user's request. If ambiguous, ask.

3. **Check the pre-condition.** If violated, refuse with a specific error:
   - "Cannot modify task-3 because its status is `done`. Done tasks are immutable history. If you need to revisit task-3's work, author a new task."
   - "Cannot remove task-2 because task-5 (`ready`) depends on it. Either complete task-5 first, change its dependency, or remove it as well."

4. **Apply the mutation in memory.**

5. **Re-run structural validation** per `plan-format.md` rules:
   - Unique ids.
   - No cycles.
   - All `depends_on:` resolve.
   - File-disjoint parallel branches.
   - Required fields present.

   If structural validation fails, refuse with a specific error pointing to the violation. Do not mutate the file.

6. **Re-run quality validation** per `plan-quality.md` (only on the tasks affected by the operation — existing `pending`/`ready` tasks not touched by this update keep their previous state). Specifically:
   - On **add task**: run hard rules H1-H9 on the new task. Run soft heuristics S1, S5, S8 on the updated DAG.
   - On **modify body**: run H1, H2, H4, H5, H9 on the modified task. Run S2-S4, S6, S8 on it.
   - On **modify `files:`**: run H3 on the modified task. Run S2 on it.
   - On **rewire `depends_on:`**: run S1, S5, H9 on the updated DAG.
   - On **remove task**: no quality re-validation needed (removing tasks doesn't introduce new quality issues).
   - On **modify tier hint** / **modify plan-level default hint**: re-validate the enum (rules #7/#8). Run S9 on the affected task(s). No structural re-validation needed (tier hints don't affect the DAG).

   Hard rule failure → refuse with rule + task + fix. Soft heuristic warnings → present and ask "save anyway? (y/N)" — default N.

7. **Regenerate the mermaid block** from scratch with current statuses (preserving `done` / `failed` / `skipped` coloring on existing tasks).

8. **Render the ASCII tree to terminal** so the user can sanity-check the new shape.

9. **Write the plan file** in place.

10. **Hand off** to the user: "Plan updated. Resume execution with `/parallel-dag-execution:execute <plan>`."

## Hard rules

- NEVER mutate `running` / `done` / `failed` / `skipped` tasks. Refuse with a clear error.
- NEVER add a `depends_on:` edge that creates a cycle.
- NEVER let two tasks share an entry in `files:` without a `depends_on:` path between them.
- Persist the new plan only if all validations pass. Partial writes are forbidden — if any rule fails after mutation, refuse and leave the file untouched.
- Regenerate the mermaid block in place — never duplicate it, never append.
- Status field on existing tasks is NEVER modified by this skill. Only the executor changes statuses.
- When adding a new task that consumes a contract defined by an already-`done` task, the new task must `depends_on:` that done task. The done task's status doesn't exempt it from H9 — sequencing rules apply for plan-coherence reasons (so a future re-execution or a reader of the plan can see the dependency). When adding a new contract-defining task, check whether existing `pending`/`ready` consumer tasks should now `depends_on:` it; if yes, mutate their `depends_on:` to include the new definer (allowed because they are `pending`/`ready`, not `done`).

## Example refusals

```
✗ Refused: Cannot modify task-2 (status: running)
   An implementer subagent is currently executing this task.
   Wait for it to complete (or fail), then update if still needed.

✗ Refused: Cannot widen task-4's files: to include src/auth.ts
   task-7 (status: pending) already declares src/auth.ts and has no
   dependency path to/from task-4. Either:
     a. Add `depends_on: [task-4]` to task-7 (or vice versa), or
     b. Choose a different file scope for task-4.

✗ Refused: Cannot remove task-1 (status: done)
   This task already shipped. To remove its work from the codebase,
   author a new revert task; do not edit the historical plan.

✗ Refused: Cannot modify task-3.model_hint (status: running)
   An implementer subagent is currently executing this task at its
   originally-resolved tier. Wait for completion (or BLOCKED), then
   the BLOCKED-retry ladder will pick up the new value if you've
   updated it by then.
```
