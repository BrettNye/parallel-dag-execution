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

The entry must show the claim was **refuted and closed**, not left open
awaiting evidence: name the contradicting ground truth (`code/handler.ts`
EXISTS / the tree read that settled it), and say the matter is closed against
HEAD.

An accompanying note on the lens's own evidentiary gap — that it asserted an
absence while citing nothing — is **accepted, not a failure.** It is useful to
whoever wrote the lens.

**Reconciled 2026-08-28 against three blind runs.** As authored, this section
also forbade the phrase "what would be needed" from appearing at all, on the
reasoning that a refuted claim has nothing to ask for. Three independent runs
(opus), given progressively more explicit instruction in
`agents/dag-audit-reconciler.md` — a trailing carve-out, then two explicit
branches, then an explicit precedence rule — all produced the refuted framing
AND an evidentiary note. Convergence across independent samples under
strengthening instruction is evidence that the constraint fought the section's
own name (`Unverifiable` reads as "could not verify — here is what would
settle it"), not that three reconcilers were careless. The substance was
correct in all three.

What this case still discriminates on is unchanged and is where its value
lives: the verdict, that the downgrade happened at all, a complete five-field
log, no deletion, and — above all — that the ground truth was **checked rather
than trusted**.
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
| `### Unverifiable` leaves the claim open, awaiting evidence, with no refutation named | the table-contradiction branch of the output contract was not applied |
| NOT READY — 1 blocking | the downgrade did not happen at all |
