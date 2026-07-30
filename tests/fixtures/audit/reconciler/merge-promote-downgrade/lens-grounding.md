## Lens: grounding
## Charter: none found in this tree.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Verdict |
|---|---|---|---|
| `applyRecompute` already exists — the worker task extends it, not creates it | §4 | `code/handler.ts:15` — `export async function applyRecompute(job: RecomputeJob): Promise<boolean>` | **VERIFIED** |
| The attempt cap is already enforced inside that function | §3 | `code/handler.ts:16` — `if (job.attempt >= RECOMPUTE_MAX_ATTEMPTS) return false;` | VERIFIED |
| `RECOMPUTE_MAX_ATTEMPTS` is imported by the worker, not redeclared there | §3 | `code/handler.ts:4` — `import { RECOMPUTE_MAX_ATTEMPTS } from './constants.js'` | VERIFIED |
| `RecomputeJob` carries `attempt` | §3 | `code/handler.ts:6-9` | VERIFIED |

### Findings

- **DEFERRED** · §4's layer map implies the worker is net-new; it is not, and the
  existing function already enforces the cap the spec re-specifies.
  - Artifact text: §4 "| Worker | `workers/recompute/src/` |" and §3 "referenced by
    the worker that runs the job".
  - Evidence: `code/handler.ts:15` defines `applyRecompute`, and `:16` already
    returns `false` at the cap. Two strategies for the positive: symbol read at
    `:15`, plus its call-shape confirmed by the `RecomputeJob` interface at `:6-9`.
  - Concrete failure: none nameable — the spec is not *wrong*, it is silent about
    what already exists, which risks a task re-implementing the cap check beside the
    one that is there.
  - Resolution: state that `applyRecompute` exists and that the worker task extends
    it; name `code/handler.ts` as the reference implementation.

### Checked, no finding
- The constant is imported rather than redeclared on the worker side (`:4`), so the
  worker half of §3 is already sound. Whether the *web client* half duplicates it is
  a placement question I did not trace — design owns it.
- No cited line number in the artifact is stale; §3, §4, and §5 cite no lines at all.

### Out of lens
- Two other lenses may report `applyRecompute` as absent. It is present at
  `code/handler.ts:15`; I verified it by reading the file rather than by grepping a
  directory that does not exist in this tree.
