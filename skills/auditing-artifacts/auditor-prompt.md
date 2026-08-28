# dag-auditor dispatch template

Template for dispatching one `dag-auditor` lens. **Dispatch every lens for a gate
in a single message** so they run concurrently.

## Context construction rules

Each lens MUST receive:

- The artifact path (and whether it is a spec or a plan).
- Its lens fragment, **verbatim** from `./lenses-spec.md` or `./lenses-plan.md`.
- The charter paths to read (not a summary — it reads them itself).
- The repo root and current branch.
- For a plan audit: the parent spec path, and that the spec is frozen.
- For a diff-scoped re-audit: the diff scope and the prior finding set.
- **Downstream artifacts** (see `SKILL.md` step 2.5): any plan that consumes this
  spec, its task statuses, and commits landed since authoring. Say explicitly when
  there are none — "none found" is different from an omitted field, and a lens told
  nothing will assume nothing exists.
- **The report path it must write** —
  `<artifact-dir>/.audit/<artifact-basename>/lens-<name>.md`. The lens writes its own
  report and returns only that path plus a one-line verdict; the orchestrator never
  handles report bodies. Create the directory before dispatching so no lens has to.

Each lens MUST NOT receive:

- Any other lens's fragment or findings. Independence is the whole design.
- A prior serial audit's conclusions presented as fact (a *resolved* finding list
  is fine; someone else's reasoning is not).
- Your own opinion about the artifact, or a hint about what you expect it to find.
  A primed lens is a lens that stopped looking.

## Prompt template

<!-- Section order (cache-friendly: stable content leads, volatile trails):
     (1) role + one-lens rule; (2) artifact + repo coordinates; (3) charter paths;
     (4) GROUND TRUTH — the step 2.6 pre-pass tables, byte-identical across all N
     dispatches, so it belongs in the stable prefix alongside charter paths;
     (5) THE LENS (the only part that varies across the fan-out — keep it late so
     the preceding sections stay byte-identical across all N dispatches);
     (6) re-audit scope + prior findings, if any. -->

```
You are ONE LENS of a parallel {spec|plan} audit. Several lenses run concurrently,
each owning a different concern and blind to the others. A reconciler merges the
findings afterward — so report ONLY within your lens, and do not pad.

ARTIFACT UNDER AUDIT: {artifact_path}    (type: {spec|plan})
REPO ROOT: {repo_root}    (branch: {branch})
{if plan}PARENT SPEC (APPROVED AND FROZEN — do not reopen its design decisions): {spec_path}{/if}

CHARTER — read these to establish what this repo actually requires:
{for each path in charter_paths: "  - " + path}
{if none}  (none found — proceed and say so; do not substitute generic best practice){/if}

GROUND TRUTH (resolved before dispatch — these are facts, not claims):
{path_table}
{charter_citation_table}

Read this table before reporting on any path. An ABSENT entry in a create-task's
`files:` is EXPECTED, not a finding. A path cited in prose as already existing
that is ABSENT is a real finding. A `frontmatter spec:` path that is ABSENT is a
provenance defect — the plan names a design document that is not there.
**You may not contradict an EXISTS.**

Table 1 (declared paths) statuses:
  - `EXISTS` — the declared path resolves to a file on disk.
  - `ABSENT` — the declared path resolves to nothing on disk.
  - `DIR` — the declared path resolves to a directory, not a file.

Table 2 (charter citations) statuses:
  - `OK` — file resolves, cited line is in range, and an anchor token matched.
  - `OK-UNANCHORED` — file resolves, cited line is in range, but no anchor could
    be extracted from the entry. Not evidence of drift.
  - `SUSPECT` — file resolves, cited line is in range, an anchor was extracted,
    and none of its tokens appear within the cited line +/- 2.
  - `MOVED` — the file exists but the cited line number is past end of file.
  - `GONE` — the file does not exist.

YOUR LENS:
{lens_fragment_verbatim}

Apply your agent's grounding discipline, severity taxonomy, and output format in
full. "No blocking findings" is an expected, successful result.

{if re_audit}
RE-AUDIT SCOPE: audit only the changed sections plus what depends on them — NOT
the whole document.
{diff}

ALREADY RESOLVED OR ACCEPTED (do not re-report):
{prior_findings}
{/if}
```

## Agent invocation example

Dispatch all lenses in one message. Include `model:` so the resolved tier is
honoured:

```javascript
// ONE message containing N Agent calls — not N sequential messages.
Agent({
  description: `Lens: ${lens.name}`,
  subagent_type: "dag-auditor",
  model: resolve_model(lens.tier),          // tier from the catalog
  prompt: <constructed-from-template-above>,
})
```

## Failure handling

A lens that errors or returns empty is a **coverage gap**, not a pass. Either
re-dispatch it once, or report it explicitly to the reconciler and the user as an
unrun lens. Never let a silent failure read as "nothing found."

## Re-dispatch

Do not re-dispatch a lens to argue with its findings — that is the reconciler's
job, and re-prompting a lens against its own output destroys its independence.
Re-dispatch only on failure, or on a genuinely new scope.
