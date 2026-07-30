# dag-audit-reconciler dispatch template

Template for the single reconciler call that follows the lens fan-out.

## Context construction rules

The reconciler MUST receive:

- Every lens report, **labeled by lens name**, complete and unedited — including
  each lens's "Checked, no finding" section, since a clean verdict is a claim it
  must adjudicate.
- The artifact path, and for a plan audit the parent spec path.
- The repo root, so it can read code to settle a contested claim.
- The names of any lenses that failed to run.

The reconciler MUST NOT receive:

- A pre-merged, pre-filtered, or truncated finding set. Merging is its job, and
  dropping anything on the way in defeats the downgrade log — the only record that
  makes suppression visible to the author.
- Your own view of which findings matter.

## Delivering the reports: files, not inline text

Six lens reports on a large artifact run to tens of thousands of tokens. Pasting
them inline works for a small run and becomes the dominant cost on a real one —
and the pressure it creates to trim or summarize them is exactly what the "complete
and unedited" rule forbids.

**Default: write each lens report verbatim to its own file and pass the paths.**
The reconciler has `Read`; one file per lens keeps attribution unambiguous and
leaves the reports byte-identical to what the lens produced.

The audit directory is defined in `./SKILL.md` step 6 — beside the artifact:

```
<artifact-dir>/.audit/<artifact-basename>/lens-<name>.md
```

e.g. for `docs/superpowers/specs/2026-07-29-foo-design.md`:

```
docs/superpowers/specs/.audit/2026-07-29-foo-design.md/lens-grounding.md
docs/superpowers/specs/.audit/2026-07-29-foo-design.md/lens-coherence.md
…
```

Pass inline text only when the reports are small enough that the extra files are
noise. Never mix: all inline, or all by path, so nothing is half-delivered.

Whichever form you use, **every lens report goes in whole** — including its
"Checked, no finding" section, since a clean verdict is a claim the reconciler must
adjudicate.

## Prompt template

<!-- Section order: (1) role; (2) coordinates; (3) unrun lenses; (4) the lens
     reports — paths by default, inline only when small (bulk, volatile, last). -->

```
You are reconciling a parallel {spec|plan} audit. {n} independent lenses each
audited one concern, blind to the others. Your output IS the audit.

ARTIFACT: {artifact_path}    (type: {spec|plan})
{if plan}PARENT SPEC: {spec_path}{/if}
REPO ROOT: {repo_root}    (branch: {branch})

LENSES RUN: {lens_names}
{if unrun}LENSES THAT FAILED TO RUN (treat as missing coverage, not as clean): {unrun_names}{/if}

Do your jobs in order: merge and dedupe (recording corroboration) · check every
proposed BLOCKING against downstream artifacts — the plan that implements this spec
(search by task id and symbol, not filename), its task statuses, and code landed
since authoring · surface contradictions without resolving them by majority, reading
the code to adjudicate · assign final severity, downgrading only with a logged
reason · resolve interacting findings JOINTLY as one change per cluster · classify
each finding DEFECT vs STALE · state the verdict.

{if downstream}DOWNSTREAM ARTIFACTS: {plan_paths_and_statuses}; commits since authoring: {shas}{/if}
{if not downstream}DOWNSTREAM ARTIFACTS: none located by the skill — search for them yourself before upholding any BLOCKING.{/if}

--- LENS REPORTS ---

{for each report: "## Lens: " + name + "\n" + report_verbatim + "\n"}
```

## Agent invocation example

```javascript
Agent({
  description: "Reconcile audit findings",
  subagent_type: "dag-audit-reconciler",
  model: resolve_model("opus"),   // the hardest judgment in the pipeline
  prompt: <constructed-from-template-above>,
})
```

The reconciler warrants the top tier by default: it adjudicates contradictions,
assigns the severities that gate the artifact, and is the only actor that can
silently lose a real finding.

## After it returns

1. Present the verdict to the user — one-line verdict first, then blocking
   findings, joint resolutions, contradictions, then the rest.
2. **Surface the downgrade log rather than burying it.** It is the author's only
   view into what was suppressed and why.
3. Record the audit in the artifact's `## Audit record` section (see `SKILL.md`).

## Re-dispatch

Re-dispatch the reconciler only if lenses were re-run. Do not re-dispatch it to
seek a different verdict — a NOT READY result is an outcome, not a failure of the
run.
