## Lens: charter conformance
## Charter: none found — no `CLAUDE.md`, `AGENTS.md`, or `.claude/audit-charter.md` in
this tree. What I could read is the workspace shape itself, below.

### Enforcement map
| Rule | Enforced by | Consequence |
|---|---|---|
| `workers/*` and `apps/web/*` may not import each other | separate workspace roots with no shared package between them — `code/handler.ts:4` imports `./constants.js`, a worker-local module, and there is no shared lib in §4's layer map | **no import path exists**; a constant needed by both must be declared twice, and the two copies cannot be kept in sync by any compiler or lint check |
| Docs-with-code | not enforced in this tree (no CI config present) | drift only |

### Findings

- **BLOCKING** · §5's docs obligation has no owning task, so the endpoint ships
  undocumented.
  - Artifact text: §5 "`docs/reference/endpoints.md` gains a row for the new route."
  - Evidence: grep of the artifact for `endpoints.md` → §5 only.
  - Concrete failure: the new route is invisible to anyone reading the reference, and
    nothing in the pipeline fails to say so.
  - Resolution: add a task owning `docs/reference/endpoints.md`.

- **DEFERRED** · §4's layer map names no per-layer reference implementation.
  - Evidence: three location strings, no file to mirror for any of them, though
    `code/handler.ts` is plainly the worker-side precedent.
  - Concrete failure: none nameable; an implementer will find the file.
  - Resolution: name `code/handler.ts` as the worker reference.

### Checked, no finding
- No layering inversion: nothing in the artifact puts business logic in a
  presentation or data-access layer.
- The worker imports its constant rather than hardcoding it (`code/handler.ts:4`),
  which is the correct shape on that side of the boundary.
- No migration, codegen, or barrel convention is touched by this artifact, so the
  usual tooling-command checks do not apply.

### Out of lens
- That the **web client** needs the same constant, and therefore that the boundary
  above forces a second declaration — I record the boundary as an enforcement fact;
  whether the duplication is acceptable is a design judgement.
