## Lens: design soundness
## Charter: none found in this tree.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Verdict |
|---|---|---|---|
| `RECOMPUTE_MAX_ATTEMPTS` is needed by two consumers | §3 | §3 names the worker and the web client explicitly | VERIFIED (in artifact) |
| A shared home for it exists | §4 | §4's layer map lists three locations, none shared | NOT-FOUND |
| The worker imports it rather than inlining it | §3 | `code/handler.ts:4` | VERIFIED |

### Findings

- **DEFERRED** · `RECOMPUTE_MAX_ATTEMPTS` is required by two consumers and §4 gives
  it no shared home, so the plan will land two declarations of one number.
  - Artifact text: §3 "`RECOMPUTE_MAX_ATTEMPTS = 3`, referenced by the worker that
    runs the job and by the web client that renders 'attempt N of 3'."
  - Evidence: §4's layer map lists `apps/api/src/periods/`, `workers/recompute/src/`,
    and `apps/web/src/app/periods/` — no shared package, lib, or contracts row. The
    worker side already imports from `./constants.js` (`code/handler.ts:4`), which is
    worker-local, so the web client cannot reach it.
  - **Concrete failure: none nameable from where I sit.** Whether the two copies can
    drift silently depends on whether a shared import path between the worker and the
    web client is available, and I cannot determine that from this artifact — there is
    no boundary or dependency configuration in this tree for me to read. If such a
    path exists, this is a tidiness point and nothing more. Reporting as DEFERRED
    rather than asserting a drift mechanism I have not established.
  - Resolution: name a shared home for the constant, or state deliberately that the
    web client's copy is a display string decoupled from the worker's guard.

- **DEFERRED** · §3 re-specifies a cap the existing implementation already enforces.
  - Evidence: `code/handler.ts:16` returns `false` at the cap.
  - Concrete failure: none — a second guard is redundant, not broken.
  - Resolution: point §3 at the existing enforcement rather than restating the rule.

### Checked, no finding
- No shared base type is widened: the artifact introduces no interface, no required
  field on an existing type, and no extension — the widening hunt has no target.
- No business logic is placed in a data-access or presentation layer: §4's three
  assignments are route→API, job→worker, rendering→web. Thin, but not inverted.
- `RecomputeJob` is not reinvented — `code/handler.ts:6-9` already defines it and the
  spec proposes no competing shape.

### Out of lens
- Whether the retry AC is falsifiable — verifiability.
