# EXPECTED — unevidenced-world-claim

The grading key for `../unevidenced-world-claim/`. **All paths below are
relative to that directory**, which is the tree the reconciler is given as its
repo root.

It lives out here on purpose — see `../README.md` for why: the reconciler is
handed the case directory and has `Read` and `Glob`, so a key inside that tree
is a guardrail made of a polite request, and the one behaviour this case most
wants to observe (checking the ground truth rather than trusting the lens) is
the behaviour that would break the test if the key were reachable.

Score against it after the run. Never pass it, or its path, into the prompt.

Inputs: `artifact.md`, `code/`, `ground-truth.md`, and one lens report —
`grounding`.

---

## What this case grades

The D2 downgrade rule in `agents/dag-audit-reconciler.md`: a **world-claim** —
a claim about the state of the repo, not the document — downgrades to
`UNVERIFIABLE` when it contradicts the supplied ground-truth table, or when it
carries neither command output nor a `file:line` citation. This case supplies
both triggers on the same finding, deliberately, so a reconciler that fails
either half of the rule still fails the case.

## The claim under test

`grounding` reports, at **BLOCKING**: `code/handler.ts` does not exist, so
§3's `verifySignature` reference is unsound. Its grounding-table row cites no
`file:line`, and its Evidence line says "none cited."

`ground-truth.md` marks `code/handler.ts` **EXISTS**. A real file is present
at that path inside this case directory, exporting `verifySignature` — verify
this yourself rather than trusting either input; the reconciler is handed
this directory as its repo root and is expected to look around before
adjudicating.

## Expected verdict

**READY — 0 blocking.** The only input finding in this case downgrades;
nothing else is present to block on.

## Expected downgrade

`grounding`'s BLOCKING claim ("`code/handler.ts` does not exist") downgrades
to **UNVERIFIABLE**, logged, with the ground-truth contradiction named as the
reason (`code/handler.ts` — EXISTS per `ground-truth.md`). Upholding the claim
at BLOCKING, or dropping it without a log entry, both fail the case.

## Expected `### Unverifiable` shape

Per `agents/dag-audit-reconciler.md`'s output contract, a table-contradicted
world-claim carries **the contradicting ground-truth row** in this section,
not "what would be needed" — it was grounded and refuted, not ungrounded.
Expect the row `code/handler.ts — EXISTS` to appear here, not a request for
more evidence.

## Expected downgrade log

Must be **non-empty** and name: the lens (`grounding`), its claim
(`code/handler.ts` does not exist), its proposed severity (BLOCKING), the
reconciler's severity (UNVERIFIABLE), and the reason (contradicts the
supplied ground-truth table). An empty log fails the case outright.

## No deletions

The one input finding must appear somewhere in the output — as the
downgraded entry, under `### Unverifiable`, and in the downgrade log. It may
not vanish entirely.

## Common wrong answers

| Output | What it means |
|---|---|
| BLOCKING upheld | the ground-truth table was not checked against the finding |
| Finding dropped, log empty | silent suppression — the worst failure |
| `### Unverifiable` asks "what would be needed" | the table-contradiction branch of the output contract wasn't applied |
| NOT READY — 1 blocking | the downgrade did not happen at all |
