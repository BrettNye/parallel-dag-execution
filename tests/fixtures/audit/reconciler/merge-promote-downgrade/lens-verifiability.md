## Lens: verifiability
## Charter: none found in this tree.

### Grounding table
| Assumption | Where | Verified at file:line | Verdict |
|---|---|---|---|
| task-route's dedupe AC pairs its absence with a positive | `plan.md` | task-route AC 2 — "returns the **same** job id and enqueues nothing" | VERIFIED |
| task-worker's retry AC pins the attempt count | `plan.md` | task-worker AC — see F1 | CONTRADICTED |
| `applyRecompute` exists to be tested | §4 | `grep -rn applyRecompute workers/` → no such directory in this tree | NOT-FOUND |

### Findings

- **BLOCKING** · `task-worker`'s only acceptance criterion cannot distinguish the
  behaviour it names from three wrong implementations, and passes on a crash.
  - Artifact text (`plan.md`, task-worker): "A job that throws is retried **up to the
    cap** and then marked failed."
  - Evidence: the criterion names no attempt count and no observable for the retry
    loop. `RECOMPUTE_MAX_ATTEMPTS = 3` (artifact §3) is never referenced by the AC.
  - Concrete failure: the AC is satisfied by (a) no retry at all — one attempt, then
    marked failed; (b) infinite retry that happens to be cancelled by the harness;
    (c) retry twice instead of three times. And "marked failed" is an absence-shaped
    outcome: if the handler throws before the retry loop is entered, the job is still
    not-succeeded, and a test asserting the failed state passes for the wrong reason.
  - Resolution: assert the attempt count exactly — a job that always throws is
    invoked `RECOMPUTE_MAX_ATTEMPTS` times and no more, with the count read from the
    same constant the implementation uses; then assert the failed marking as a
    positive with the successful path as its control.

- **BLOCKING** · Nothing under test exists: `applyRecompute` is absent from the tree.
  - Evidence: `grep -rn "applyRecompute" workers/` — the `workers/` directory does
    not exist here.
  - Concrete failure: `task-worker`'s test file has no subject.
  - Resolution: confirm the function's home before writing its acceptance criteria.

### Checked, no finding
- task-route's dedupe AC is genuinely falsifiable: "returns the same job id" is the
  positive control that keeps "enqueues nothing" from passing on a crash. This is the
  correct shape and should not be flagged.
- task-endpoints-doc's ACs name the specific strings the row must contain, so they
  are checkable by reading rather than by asserting a constant against itself.

### Out of lens
- Whether R3 has an owning task at all — coverage.
