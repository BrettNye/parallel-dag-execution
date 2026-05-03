# parallel-dag-execution

DAG-aware planning + continuous parallel subagent execution for [Claude Code](https://claude.com/claude-code). Companion to the [superpowers](https://github.com/obra/superpowers) plugin.

## What it does

Where `superpowers:subagent-driven-development` dispatches one implementer subagent at a time per task, this plugin runs a **DAG-aware coordinator** that continuously dispatches multiple parallel subagents along the dependency graph — every task becomes ready as its upstream completes.

## Skills

- **`writing-dag-plans`** — author a plan with explicit `depends_on` and `files` per task. Enforces file-disjoint parallel branches at authoring time.
- **`executing-dag-plans`** — read a DAG plan, topo-sort, dispatch ready tasks in parallel. Per-task two-stage review (spec then quality). Auto-retry-once on `BLOCKED` with model upgrade. Halt-downstream on failure; let parallel branches finish.
- **`updating-dag-plans`** — mutate `pending`/`ready` tasks mid-flight. `running`/`done`/`failed`/`skipped` are immutable history.

## Slash commands

- `/parallel-dag-execution:plan <spec>` — author a DAG plan
- `/parallel-dag-execution:execute <plan>` — run it
- `/parallel-dag-execution:update <plan>` — change it mid-flight

## Subagents bundled

- `dag-implementer` — TDD-disciplined task implementer.
- `dag-spec-reviewer` — spec compliance checker (catches over-build and under-build).
- `dag-quality-reviewer` — code quality reviewer.

## Install

Once the repo is on GitHub:

```
/plugin marketplace add <your-github-handle>/parallel-dag-execution
/plugin install parallel-dag-execution@parallel-dag-execution
```

## Local development

Clone and load directly without going through a marketplace:

```
claude --plugin-dir /path/to/parallel-dag-execution
```

Hot-reload after edits with `/reload-plugins`.

## Composition with superpowers

This plugin assumes you've already invoked `superpowers:brainstorming` to produce the spec. Subagent definitions auto-load `superpowers:test-driven-development`, `superpowers:verification-before-completion`, and `superpowers:requesting-code-review` via the `skills:` frontmatter field — no copy-paste of TDD discipline into prompts.

## Visualization

Every plan write or update produces:

1. A **mermaid block embedded at the top of the plan file**, regenerated from scratch each time. Status-driven node coloring (`pending`/`ready`/`running`/`done`/`failed`/`skipped`).
2. An **inline ASCII tree printed to the terminal** for at-a-glance verification.

The plan file is one source of truth — visualization, task definitions, and live execution state all live in it.

## License

MIT — see [LICENSE](./LICENSE).
