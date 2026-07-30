# parallel-dag-execution

DAG-aware planning + continuous parallel subagent execution for [Claude Code](https://claude.com/claude-code). Companion to the [superpowers](https://github.com/obra/superpowers) plugin.

## What it does

Where `superpowers:subagent-driven-development` dispatches one implementer subagent at a time per task, this plugin runs a **DAG-aware coordinator** that continuously dispatches multiple parallel subagents along the dependency graph — every task becomes ready as its upstream completes.

## Skills

- **`writing-dag-plans`** — author a plan with explicit `depends_on` and `files` per task. Enforces file-disjoint parallel branches **and contract coherence** at authoring time via a hard/soft rule set (H1–H11 / S1–S11): refuses compound tasks, missing or absent producers for consumed contracts, and bare spec-pointer acceptance criteria; warns on unanchored cross-cut interfaces and decomposition smells.
- **`executing-dag-plans`** — read a DAG plan, topo-sort, dispatch ready tasks in parallel. Per-task review (two-stage spec→quality, or a merged single-pass review for small/mechanical tasks). Auto-retry-once on `BLOCKED` with model upgrade. Halt-downstream on failure; let parallel branches finish.
- **`updating-dag-plans`** — mutate `pending`/`ready` tasks mid-flight. `running`/`done`/`failed`/`skipped` are immutable history.
- **`auditing-artifacts`** — audit a spec (gate 1) or a plan (gate 2) by fanning out independent single-concern **lenses in parallel**, then reconciling them into one severity-classified verdict. See below.

## Parallel lens auditing

```
brainstorm → spec → [gate 1: audit-spec] → writing-dag-plans → [gate 2: audit-plan] → executing-dag-plans
```

A broad "audit this spec" prompt draws **one** sample of which concern the auditor looks hardest at — so a later round finds real material because it is a *new draw*, not a deeper look. Worse, each serial round reads the artifact **as fixed by the previous round**, so the fresh-context independence that makes auditing work decays with every round. Parallel lenses convert that luck into coverage while keeping independence maximal.

- **Spec lenses (6):** `absence` · `ambiguity` · `grounding` · `charter` · `coherence` · `design`
- **Plan lenses (7):** `coverage` · `dag-integrity` · `grounding` · `charter` · `context-sufficiency` · `verifiability` · `coherence`

Three rules do most of the work:

1. **Severity is gated on a named failure.** DRY/SRP/SoC observations are `DEFERRED` unless the lens can name the concrete failure — a compile error, a boot-time DI failure, an enforced CI check, or two copies that *will* silently drift because no shared import path exists. An unbounded criterion with gating power is what produces endless revision cycles.
2. **Claims are grounded in code.** `file:line` for positive claims; **two independent search strategies** for negative ones; docs and `CLAUDE.md` are never evidence about code. A lens's "no finding" is itself a claim, held to the same bar.
3. **The reconciler resolves interacting findings jointly.** Fixing findings one at a time is how a fix for A becomes finding B next round. Contradictory lens verdicts are surfaced explicitly and adjudicated on **evidence completeness, not lens count** — one lens that traced the whole mechanism beats five that traced one end. Severity may be downgraded but never silently deleted; every downgrade is logged.

Gate 2 may not reopen gate 1: the spec is frozen once planning starts. Re-audits are **diff-scoped** — the changed sections plus their dependents, never a whole-document re-read, which is what reopens settled ground.

Per-repo knowledge lives in an optional `.claude/audit-charter.md` (enforcement map, recurring bug classes, named per-layer reference implementations, frozen decisions). Without it the lenses read the repo's own `CLAUDE.md`, convention, and boundary docs and say so.

## Multi-plan superspecs (fan-out)

When a spec fans out into ~3+ interlocking pieces with separate review/lifecycles (e.g. a shared library + its first consumer, or a core engine + N adapters), `writing-dag-plans` authors a thin **superspec-charter** first — the connective tissue no single plan owns: the cross-plan contract surface (shared types/schemas), shared invariants every child must uphold, and the build-order gate between children. You then run the skill once per child plan, pulling children one at a time. Single-deliverable specs skip the charter (one spec → one plan). You don't invoke this separately: run `/parallel-dag-execution:plan` as usual and the skill's fan-out checkpoint decides whether to charter first.

## Slash commands

- `/parallel-dag-execution:audit-spec <spec>` — gate 1: audit a spec before planning
- `/parallel-dag-execution:plan <spec>` — author a DAG plan
- `/parallel-dag-execution:audit-plan <plan>` — gate 2: audit a plan before execution
- `/parallel-dag-execution:execute <plan>` — run it
- `/parallel-dag-execution:update <plan>` — change it mid-flight

Both audit commands accept `--full` to force a whole-artifact re-audit instead of a diff-scoped one.

## Subagents bundled

- `dag-implementer` — TDD-disciplined task implementer.
- `dag-spec-reviewer` — spec compliance checker (catches over-build and under-build).
- `dag-quality-reviewer` — code quality reviewer.
- `dag-merged-reviewer` — combined spec + quality review in one pass for small/mechanical tasks (opt-in via `review_mode: merged`).
- `dag-auditor` — one lens of a parallel pre-execution audit. Dispatched N times concurrently with a different lens each time; the lens arrives in the prompt, so adding a lens is a catalog row, not a new agent.
- `dag-audit-reconciler` — merges the lens reports into one verdict. Distinct from `dag-spec-reviewer`: the auditors read the **document before any task runs**; the reviewers read **committed code** during execution.

## Install

Once the repo is on GitHub:

```
/plugin marketplace add BrettNye/parallel-dag-execution
/plugin install parallel-dag-execution@parallel-dag-execution
```

## Local development

Clone and load directly without going through a marketplace:

```
claude --plugin-dir /path/to/parallel-dag-execution
```

Hot-reload after edits with `/reload-plugins`.

**If you installed from a directory marketplace, `/reload-plugins` will not pick up
your edits.** It re-reads a version-pinned copy under
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, so a `plugin.json` version
bump needs a *new* cache directory and reloading cannot create one. Refresh the
marketplace's view of the directory first, then reinstall:

```
/plugin marketplace update <marketplace-name>
/plugin install <plugin>@<marketplace-name>
```

Skipping the `update` step is silent — the reload reports success and keeps serving the
old copy.

## Testing

`tests/fixtures/` holds fixtures for both halves of the plugin: plan-validation
fixtures under `contracts/`, `review-mode/`, and `tiers/`, and audit fixtures under
`audit/`.

Audit fixtures are prompt-level, not unit tests — a lens is a model dispatch, so there
is no assertion harness. Each is scored by dispatching the named lens at it and
checking the report against the header's declared severity and substrings. Start at
[`tests/fixtures/audit/README.md`](tests/fixtures/audit/README.md), which documents the
`should-flag` / `should-defer` / `should-pass` buckets, why the middle one exists, and
which lenses have no fixture yet. `dag-audit-reconciler` has a separate harness with
its grading keys held outside the tree it reads.

## Composition with superpowers

This plugin assumes you've already invoked `superpowers:brainstorming` to produce the spec. Subagent definitions auto-load `superpowers:test-driven-development`, `superpowers:verification-before-completion`, and `superpowers:requesting-code-review` via the `skills:` frontmatter field — no copy-paste of TDD discipline into prompts.

## Visualization

Every plan write or update produces:

1. A **mermaid block embedded at the top of the plan file**, regenerated from scratch each time. Status-driven node coloring (`pending`/`ready`/`running`/`done`/`failed`/`skipped`).
2. An **inline ASCII tree printed to the terminal** for at-a-glance verification.

The plan file is one source of truth — visualization, task definitions, and live execution state all live in it.

## License

MIT — see [LICENSE](./LICENSE).
