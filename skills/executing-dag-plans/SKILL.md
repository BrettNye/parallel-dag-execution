---
name: executing-dag-plans
description: Use when you have a DAG plan authored by `writing-dag-plans` and want to execute it with continuous parallel subagent dispatch. Maintains a ready queue, dispatches multiple implementer subagents per tick, runs spec+quality review per task, auto-retries-once on BLOCKED one step up (next model tier, or higher effort at the top tier), and halts only the failed branch's downstream lineage on hard failure (parallel branches keep going). Resumable — re-invoke on a partially-executed plan to pick up where it left off.
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

The executor is a controller loop that moves forward on events, not on user prompts. A **tick** is one pass through the steps below. The first tick runs when the skill starts. After that a tick runs each time a dispatched subagent finishes: in Claude Code, subagents run in the background and the controller is woken when each one completes, so the run advances without anyone saying "continue". Within a tick:

The bookkeeping is done by `plan-state`, a script at `skills/writing-dag-plans/plan-state` under the plugin root (`sh <path> <command> <plan>`). It owns every step with one right answer, so the controller spends its turns on judgment: dispatch, review results, failures.

1. Run `plan-state check <plan>`. It reads the plan fresh, so `/update` changes made between ticks are picked up. Any output halts the run and is shown to the user. This is also the **file-scope tripwire**: a ready task that shares a file with a running task has no dependency path to it, which is rule 4.
2. Run `plan-state ready <plan>`. It prints the ids of tasks whose dependencies are all `done`.
3. Promote each listed `pending` task with `plan-state set <plan> <id> ready`.
4. **Dispatch in parallel:** for each ready task, dispatch a fresh implementer subagent via the Agent tool. Pass `model: resolve_model(resolve_tier(task, 'model'))` (resolver defined in `../writing-dag-plans/plan-format.md` §Tier resolution). The implementer's per-task field is `model_hint`; absent that, `default_model_hint`; absent that, `standard`. The dispatched `subagent_type` resolves in order: the task's `implementer:` field, then the plan-level `default_implementer`, then `dag-implementer` (see `../writing-dag-plans/plan-format.md` §Per-task frontmatter schema). Mark it with `plan-state set <plan> <id> running`. **All ready tasks dispatch in the same tick — that's the parallelism.** The BLOCKED retry is one step above the original resolved tier (cheap→standard, standard→opus), not a fixed override; for an `opus` task the step is effort, not model (see Implementer status handling).

   When constructing each implementer dispatch, substitute the absolute path to `skills/executing-dag-plans/git-commit-safe` into the prompt's `{git_commit_safe_path}` placeholder (resolve it from the plugin root). Implementers commit through this helper so concurrent dispatches in the same tick never race on the shared git index.

   Pre-flight check: before the first dispatch tick, verify every distinct `implementer:` value referenced by the plan resolves in the current harness's agent registry. If any are missing, halt with a clear error naming the missing subagent_type(s) and instruct the user to deploy them (`vault.sync-agents`) and `/clear` so the harness reloads. Newly-deployed `.claude/agents/*.md` files only register at session start in Claude Code today. Also validate every `*_hint` value across all tasks and every plan-level `default_*_hint` is in `{cheap, standard, opus}`. Halt with a clear error naming the offending task id (or `plan-level` for a `default_*_hint` field), field name, and bad value if any fails — this catches hand-edits that bypassed the writing-dag-plans validator. No silent fallback to `standard`. Also validate every `review_mode` / `default_review_mode` is in `{merged, split}` (halt naming the offending task id or `plan-level`, field, and value — no silent fallback). Step 1's `plan-state check` performs these enum checks and the `spec:` check below; the registry checks need the harness and stay with the controller. And if any task resolves to `merged`, require `dag-merged-reviewer` in the agent registry (same registry pre-flight as `implementer:` values); halt with the deploy-the-agent message if missing. Also resolve the plan-level `default_implementer` (if present) against the agent registry — the same check as `implementer:`, since a plan-level typo must not survive to dispatch; halt with a clear error naming the field and the unregistered value, no silent fallback. Also resolve `spec:` if present; a `spec:` that does not resolve to a readable single file halts, naming the field and the offending value, no silent fallback. Also run `plan-state preflight <plan>` on every invocation, at start and on resume, before the first dispatch; on resume, run it after `running` tasks are reset to `ready`. It runs `check`, then reads the text of `pending` and `ready` tasks for path defects: P1 a path the text says to edit that is not in the task's `files:`, P2 a missing path another task creates with no dependency path to it, P3 a missing path no task creates or a line citation past the end of its file, P4 a path that a task able to run at the same time changes. Exit 1 means at least one error: halt before any dispatch, print the findings, and change no task's status. Lines marked `warning:` with exit 0: print them and proceed, because an unattended run has no one to ask. Exit 2: halt.

   Also locate charter material once, before the first tick — root and nested `CLAUDE.md`/`AGENTS.md`, and `.claude/audit-charter.md` if present — and run `../auditing-artifacts/resolve-declared-paths <plan> <repo-root> <charter...>` for its charter citation table; only the citation table is consumed here, because an executor's plan describes files that do not exist yet by design, so the declared-paths table carries no signal on this side. Substitute the located charter sections into every dispatch's `{charter_sections_for_role}` placeholder, and the resulting table into `{charter_citation_table}` (see the four prompt templates). If the helper cannot run, substitute `citation pre-pass did not run` into `{charter_citation_table}` rather than rendering it empty — an empty table would present possibly-stale charter prose as verified, the exact hazard the freshness mechanism exists to remove.
5. Continue per-task review chains (one per running task — they progress in parallel across the DAG).
6. As tasks reach terminal states, record them with `plan-state set <plan> <id> done` or `... failed`. Each `set` writes the status and redraws the mermaid block; `failed` also marks the downstream tasks `skipped` and prints their ids.
7. **Advance, don't stop.** Process every result that has arrived (status handling, the next review stage, status persistence). If that made tasks ready, run the next tick in the same turn. End the turn only to wait for running subagents, and print `plan-state tree <plan>` when you do. The run ends when the `ready` set is empty and nothing is `running` (see Failure handling); then print the final report. Do not end a turn to ask whether to continue. The user can interrupt at any time, and an `/update` made between ticks is read by the next tick's step 1.

   If the harness runs subagents in the foreground (each Agent call blocks until it returns), dispatch all ready tasks in one message, handle the results when they return, and start the next tick in the same turn.

## Per-task review chain

Once an implementer reports DONE, branch on `resolve_review_mode(task)` (resolver in `../writing-dag-plans/plan-format.md` §Review-mode resolution):

`split` (default) — the two-call chain:
```
implementer DONE
  → dispatch dag-spec-reviewer  (model: resolve_model(resolve_tier(task, 'spec_reviewer')))
      → APPROVED → dispatch dag-quality-reviewer  (model: resolve_model(resolve_tier(task, 'quality_reviewer')))
          → APPROVED → mark task `done`, persist status
          → ISSUES → plan-state round → exit 0: re-dispatch implementer with quality feedback → loop
      → ISSUES → plan-state round → exit 0: re-dispatch implementer with spec feedback → loop
```

`merged` — one combined call:
```
implementer DONE
  → dispatch dag-merged-reviewer  (model: resolve_model(resolve_tier(task, 'quality_reviewer')))
      → BOTH verdicts APPROVED → mark task `done`, persist status
      → EITHER verdict ISSUES → plan-state round → exit 0: re-dispatch implementer with the combined feedback → merged re-review → loop
```

**Reading a verdict.** Take it from the report's closing line, `VERDICT: APPROVED` or `VERDICT: ISSUES` (a merged review closes with a `SPEC:` line and a `QUALITY:` line), not from the prose above it. A report is malformed when that line is missing, holds anything else, or appears more than once. Re-dispatch the reviewer once, fresh, on the same commit. If the second report is malformed too, mark the task `failed` with the reason "reviewer gave no single verdict". Do not settle it by checking the work yourself: a verdict the controller reaches is a skipped review.

**Review-round cap.** A fix round is one re-dispatch of the implementer in response to an ISSUES verdict from any reviewer: spec, quality, or merged (a merged review with either verdict ISSUES is one fix round). A reviewer re-run because its report had no single verdict line is not a fix round, and neither is the fresh dispatch of a `running` task after a restart. `plan-state` owns the count, in the task's `review_rounds:` field, and the cap of 3; never read or compare the count yourself. On every ISSUES verdict, run `plan-state round <plan> <id>` before anything else:

- exit 0 (it prints the new count): re-dispatch the implementer as before;
- exit 1 (it prints `plan-state: <id>: review cap reached (3 fix rounds)`): run `plan-state set <plan> <id> failed`, which cascades to downstream tasks as any failure does, and give the printed line as the task's reason in the final report, the same way as "reviewer gave no single verdict". Do not write the reason into the plan;
- exit 2: halt the run and show the output.

So an implementer gets at most 3 fix attempts across all of a task's reviews, and the fourth ISSUES verdict fails the task. `set` rewrites only the status line, so the count survives the resume reset of `running` to `ready`. A crash between `round` and the re-dispatch uses up that round, and a task at 3 that is reset and dispatched again fails on its next ISSUES verdict. Nothing lowers the count.

Reviewer tiers fall back per-task → plan-level default → `standard`. Review-issue re-dispatch of the **implementer** uses the original resolved implementer tier (NOT the BLOCKED-upgraded one). Spec-before-quality ordering only matters for `split`; `merged` is gated (by the writing-dag-plans validator / author choice) to small low-risk tasks where it doesn't.

## Implementer status handling

| Status | Action |
|---|---|
| **DONE** | Proceed to review chain. |
| **DONE_WITH_CONCERNS** | Read concerns. If correctness/scope, address before review. If observations only, log and proceed. |
| **NEEDS_CONTEXT** | Provide missing context, re-dispatch. |
| **BLOCKED** | Auto-retry once, one step up. `cheap` and `standard` tasks retry on the next model tier (cheap→standard, standard→opus). An `opus` task has no tier above it, so it retries on `opus` with `effort: "high"` on the Agent call. If the agent's pinned effort is already `high` or above, or the harness's Agent tool has no `effort` parameter, an `opus` task gets no retry and is marked `failed`. If the retry also reports BLOCKED, mark task `failed`. Table and retry prompt: `./implementer-prompt.md` §Re-dispatch on BLOCKED. |
| **ISSUES** (a reviewer's verdict) | Run `plan-state round <plan> <id>` first. Exit 0: re-dispatch with the issue list. Exit 1: `plan-state set <plan> <id> failed`; the reason is the line `round` printed. Exit 2: halt. See Review-round cap. |

## Failure handling — D + B

When a task is marked `failed` (after auto-retry):

1. Walk transitive downstream of the failed task via the `depends_on:` graph.
2. Mark every task in that downstream set `skipped`.

   `plan-state set <plan> <id> failed` does steps 1 and 2 in one call and prints the skipped ids.
3. Tasks NOT in the failed branch's downstream continue dispatching as their deps clear.
4. Run terminates when:
   - `ready` set is empty AND
   - No tasks are `running`.
5. Final report distinguishes: `<N> done`, `<F> failed`, `<S> skipped (downstream of failure)`.

The semantic is `make -k --keep-going`: extract maximum useful work from the DAG before halting.

## Visualization

Per the shared visualization contract (see `../writing-dag-plans/plan-format.md` §Mermaid block specification and §ASCII tree rendering):

- After each task's status transition (`ready` → `running`, `running` → `done`/`failed`), regenerate the mermaid block in the plan file. Status drives node coloring. `plan-state set` does this on every change; `plan-state render` redraws it on its own.
- Whenever the controller ends a turn to wait for subagents, print the ASCII tree (`plan-state tree <plan>`) to the terminal with current status icons. This gives the user progress without opening the plan file, without printing the tree on every tick.

## Resumability

Because all task statuses live in the plan file's frontmatter, re-invoking `/parallel-dag-execution:execute` on a partially-executed plan picks up exactly where it left off:

- `pending` tasks await deps.
- `ready` tasks dispatch on the next tick.
- `running` tasks — if the controller was killed mid-tick, the implementer subagent's work was lost. Reset these to `ready` on resume (`plan-state set <plan> <id> ready`) so they re-dispatch. (The implementer commits per task, so partial work survives in git history; the rerun picks up from the last commit.) Then run `plan-state preflight` (see Pre-flight check) before the first dispatch.
- `done` / `failed` / `skipped` are immutable — never re-run.

## Hard rules

- NEVER dispatch two implementers whose `files:` lists overlap. The tripwire MUST fire if the planner missed a conflict — this is a hard halt with a clear error explaining which two tasks overlap on which file.
- NEVER mutate `running` / `done` / `failed` / `skipped` tasks via this skill — those statuses are managed by the dispatch loop only.
- NEVER dispatch the implementer subagent with the whole plan as context. Only the task's own text + immediate-deps context. Plan file is for the executor, not the workers.
- Persist plan file changes after every status transition. The plan file is the source of truth — if the controller dies, the plan file's status field is what survives.
- Every task gets both verdicts, spec compliance and code quality, before it is `done`. In `split` mode spec review runs first and quality review only after it approves; in `merged` mode one reviewer returns both verdicts in one pass.
- ALL implementer commits go through `git-commit-safe` (atomic-mutex + path-scoped commit). The dispatch MUST inject `{git_commit_safe_path}`. This is what prevents `index.lock` contention and cross-task stage-bundling when multiple implementers commit concurrently.

## Dispatch templates

See:
- `./implementer-prompt.md` for the `dag-implementer` dispatch.
- `./spec-reviewer-prompt.md` for the `dag-spec-reviewer` dispatch.
- `./quality-reviewer-prompt.md` for the `dag-quality-reviewer` dispatch.

These templates include the exact context construction logic — what to include from the plan, what to exclude, how to format the upstream-deps summary.
