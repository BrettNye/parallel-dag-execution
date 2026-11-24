# Ground truth — unevidenced-world-claim

Supplied to the reconciler alongside the lens reports, exactly as
`agents/dag-audit-reconciler.md`'s D2 downgrade rule describes: "a world-claim
… downgrades to `UNVERIFIABLE` when it contradicts the ground-truth tables
supplied in the prompt." Paths below are relative to this case directory,
which the reconciler receives as its repo root — it has `Read` and `Glob` and
is expected to check rather than trust either side.

| Path | Verdict | Notes |
|---|---|---|
| `code/handler.ts` | EXISTS | Present at this case's root; exports `verifySignature(rawBody, header, secret)`. |
