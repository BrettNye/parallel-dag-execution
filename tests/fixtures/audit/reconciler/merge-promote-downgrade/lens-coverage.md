## Lens: coverage
## Charter: none found in this tree.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Verdict |
|---|---|---|---|
| R1 (route returns 202 + job id) has an owning task | §2 | `plan.md` task-route + its first AC | VERIFIED |
| R2 (dedupe) has an owning task | §2 | `plan.md` task-route second AC | VERIFIED |
| R3 (audit row) has an owning task | §2 | none — see F1 | NOT-FOUND |
| §5's docs obligation has an owning task | §5 | `plan.md` task-endpoints-doc | VERIFIED |
| `applyRecompute` is a symbol the worker task must create | §4 | `grep -rn applyRecompute plan.md` → 0 hits | NOT-FOUND |

### Findings

- **BLOCKING** · R3 has no owning task; every acceptance criterion in the plan goes
  green while no audit row is ever written.
  - Artifact text: "**R3** — Every recompute writes an audit row naming the operator
    and the period."
  - Evidence: `plan.md` declares three tasks — `task-route`, `task-worker`,
    `task-endpoints-doc`. Two strategies: (1) content grep of `plan.md` for
    `audit|operator` → zero hits; (2) read every task's `files:` — no migration, no
    repository, no audit table appears in any of them.
  - Concrete failure: the feature ships with no attribution for a privileged
    operation on closed financial periods, and nothing fails. R3 is the only
    requirement with a compliance character, and it is the one with no owner.
  - Resolution: add a task owning the audit-row write, with the period id and
    operator id asserted on a real insert.

- **BLOCKING** · The worker task will call a function that does not exist.
  - Artifact text: §4 assigns the worker to `workers/recompute/src/`.
  - Evidence: `grep -rn "applyRecompute" plan.md` returns zero hits, so no task
    creates it.
  - Concrete failure: `task-worker` has nothing to extend and will fail to compile.
  - Resolution: add the function to `task-worker`'s implementation sketch.

### Checked, no finding
- No over-build: every task's deliverable traces to a numbered requirement or to §5.
- §6's out-of-scope items (recurring schedules, reopening a period) appear in no
  task's `files:` — correctly excluded.

### Out of lens
- Whether `RECOMPUTE_MAX_ATTEMPTS` should be shared rather than duplicated — design.
