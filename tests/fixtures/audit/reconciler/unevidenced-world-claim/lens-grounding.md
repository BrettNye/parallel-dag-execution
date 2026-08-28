## Lens: grounding
## Charter: none found in this tree.

### Grounding table
| Assumption | Where in artifact | Verified at file:line | Verdict |
|---|---|---|---|
| `verifySignature` already exists in `code/handler.ts` | §3 | — | NOT-FOUND |

### Findings

- **BLOCKING** · §3 claims a reusable `verifySignature` function already
  exists in `code/handler.ts`, but no such file is present in this repo.
  - Artifact text: §3 "`verifySignature(rawBody, header, secret)` in
    `code/handler.ts` already implements the constant-time comparison the
    route must call."
  - Evidence: none cited — `code/handler.ts` does not exist.
  - Concrete failure: a task written against §3 will import a function from a
    file that is not there and fail to compile.
  - Resolution: strike §3's claim, or have the owning task write
    `verifySignature` from scratch instead of extending it.

### Checked, no finding
- R1 and R2's HTTP semantics are internally consistent with each other.

### Out of lens
- Whether the route itself already exists — coverage.
