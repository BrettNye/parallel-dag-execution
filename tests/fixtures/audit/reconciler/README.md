# Reconciler fixtures

The lens fixtures grade one lens against one artifact. These grade
`dag-audit-reconciler` against a **pre-canned set of lens reports** — the only way
to test the four jobs that are uniquely its own, and the only component whose
regressions are otherwise invisible.

Why it needs its own harness: a lens either finds the defect or doesn't, and you can
read its report to tell. The reconciler's failures are *absences* — a finding
silently dropped, a promotion never made, a contradiction collapsed by vote, a
downgrade with no logged reason. None of those look wrong on the page.

## Layout

One directory per case:

```
<case>/
  EXPECTED.md          the contract — read this first
  artifact.md          the spec the lenses audited
  plan.md              a downstream plan (present when the case tests STALE)
  code/…               real files, so a contradiction can be adjudicated
  lens-<name>.md       the inputs, in the shape dag-auditor emits
```

## Running one

Dispatch `dag-audit-reconciler` with the lens-report paths, the artifact path, and
the case directory as repo root — exactly as `auditing-artifacts` step 7 would. Then
score its output against `EXPECTED.md`.

**Do not paste `EXPECTED.md` into the prompt.** It names the answers.

## What every case checks

| Job | The regression it catches |
|---|---|
| Merge + record convergence | Two lenses' findings counted twice, or one lens's evidence dropped from the merged citation |
| Promotion | A DEFERRED finding stays deferred when another lens supplied the concrete failure it lacked — invisible to every lens alone |
| Downgrade **with a logged reason** | Severity lowered silently. The log is the author's only view into suppression |
| Contradiction on **evidence completeness, not majority** | The outnumbered-but-correct lens loses a vote |
| Stale vs defect | A defect a downstream artifact already handles gates the verdict |
| No deletions | Any input finding absent from the output entirely |

## Cases

- **`merge-promote-downgrade/`** — all six in one pass. The contradiction is
  deliberately rigged so the **majority is wrong**: two lenses claim a symbol is
  absent, each from a single search; one cites it at `file:line`. A reconciler that
  counts votes fails.
