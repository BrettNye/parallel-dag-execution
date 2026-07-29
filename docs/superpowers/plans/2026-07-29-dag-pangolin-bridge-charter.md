---
id: superspec-charter-dag-pangolin-bridge
title: "DAG plan → Pangolin orch bridge"
type: superspec-charter
created: 2026-07-29
---

# DAG plan → Pangolin orch bridge

## Intent

Close the loop from an authored DAG plan through unattended pangolin execution,
implementer concerns captured as stoa tasks, and a follow-up lane of impl+verify
pairs that produces reviewable patches by morning. Driving spec:
`docs/superpowers/specs/2026-07-29-dag-pangolin-bridge-design.md` (commit
`7aafe87`, this repo). Pangolin is **not modified** — the follow-up "pattern" is
plan.json configuration over its shipped `pipeline` pattern.

## Decomposition — the children

- **`bridge-stoa`** — four pure core modules (`lock-path`, `four-section`,
  `pangolin-bundle`, `follow-up-plan`) behind three thin CLI commands
  (`task-import`, `task-materialize`, `task-close`). Repo: `BrettNye/stoa`
  (FSL-1.1-MIT). Plan: `docs/superpowers/plans/2026-07-29-bridge-stoa-dag.md`
  **in the stoa repo**.
- **`bridge-plugin`** — the `to-plan-json` converter skill, the two
  `pangolin-setup.sh` capabilities, implementer concern emission, and converter
  fixtures + shell test. Repo: `BrettNye/parallel-dag-execution` (MIT). Plan:
  `docs/superpowers/plans/2026-07-29-bridge-plugin-dag.md` **in this repo**.

Why a charter for two children: they live in different repos with different
licenses, PR cadences, and release lifecycles, and **four contracts cross the
repo boundary** with no code-level link to enforce them. Nothing imports across
the seam, so drift would be silent — exactly the case a charter exists for.

## Interfaces / contracts between pieces

**C1 — the `outputs/concerns` envelope.** Emitted by a prompt in `bridge-plugin`
(`agents/dag-implementer.md`), parsed by code in `bridge-stoa`
(`core/four-section.ts`). Exact shape:

```json
{ "schemaVersion": 1,
  "concerns": [
    { "title": "string",
      "files": ["repo-relative canonical path", "…"],
      "scope": "string",
      "out_of_scope": "string",
      "verification": "string" }
  ] }
```

Written to `outputs/concerns` — **no file extension**, because `outputRefs` keys
are literal paths and `concerns.json` would silently fail to bind. `schemaVersion`
is the literal `1`. A reader seeing any other value must reject loudly, not
harvest nothing.

**C2 — canonical lock-path form.** `bridge-stoa` owns the definition
(`core/lock-path.ts`); `bridge-plugin`'s converter validates against it and
**refuses rather than rewrites**. A path is canonical iff all hold: no leading
`./`; forward slashes only (no `\`); no repeated slashes; no trailing slash; not
absolute; contains no `*`, `?`, or `[`.

**C3 — `needs` key naming.** Two conventions, one per lane, each with a producer
in one repo and a consumer in the other:

| Lane | Key form | Emitted by | Consumed by |
|---|---|---|---|
| A (main) | `NN-<task-id>`, zero-padded topological index from `01` | `bridge-plugin` converter | `bridge-plugin` `apply-closure/pangolin-setup.sh` |
| B (follow-up) | exactly `work` | `bridge-stoa` `follow-up-plan.ts` | `bridge-plugin` `apply-work/pangolin-setup.sh` |

Lane B's key is not a free choice — pangolin's `respawnLineage` hardcodes
`fixNeeds.work`, so a spawned fix receives the patch under that name regardless
of what the authored item used.

**C4 — plan.json conformance.** Both producers emit pangolin's `Run` /
`WorkItem` shape: required `id`, `queue`, `items[]`, and per item `id`,
`executor`, `inputs`, `depends_on`, `resourceLocks`. Lane A targets queue `dag`
(no pattern bound); lane B targets queue `followups` (`pipeline` bound).

## Shared invariants

**I1 — lock strings are byte-identical across lanes.** A lane-B follow-up
touching a file a lane-A task is editing must serialize behind it. Pangolin
matches lock keys by exact set membership, so any spelling difference makes the
lock a silent no-op — indistinguishable from a working lock until two patches
collide. Enforced from both ends: stoa canonicalizes through one function; the
plugin converter refuses non-canonical input.

**I2 — four-section completeness is a precondition, never forced.** A concern
that cannot be honestly expressed in all four sections is not emitted at all; a
task that fails the readiness check is skipped and reported, never materialized.
No `force` flag exists anywhere in this feature.

**I3 — every emitted plan.json item carries a non-empty `inputs.subagent`.**
`orch validate` does not check this, but dispatch throws on it. Both producers
must self-check; validating clean is not sufficient evidence.

**I4 — concerns are produced only by the implementer, never a reviewer.** A
reviewer able to defer a finding to a follow-up queue gains an escape valve on
hard pass/fail calls. The implementer does not render the verdict, so its
deferrals cannot weaken the gate.

**I5 — retry is bounded at one, in lane B only.** `maxFixAttempts: 1`. On second
failure the stoa task lands `failed` with the verifier's notes. Lane A has no
gate and no auto-fix.

## Build order

```
charter (this file)
   │
   ├──▶ bridge-stoa      ← FIRST: makes C1/C2 executable, tested code
   │
   └──▶ bridge-plugin    ← SECOND: validates against a real definition
```

`bridge-stoa` first. Nothing imports across the seam, so the children are
technically parallel — but sequencing stoa first turns C1 and C2 from prose into
tested functions, so the plugin child is written against something real. Accepted
partial state: after `bridge-stoa` lands, stoa has three commands with no
producer feeding them; they are inert until `bridge-plugin` ships.

**Because reviewers never see this charter** — the task body IS the binding spec
— every child task consuming a contract or invariant above must **inline the
requirement text** in its acceptance criteria, citing the charter section as
provenance (e.g. "per Charter §C2: no leading `./` …"). A bare "upholds Charter
C2" is unverifiable at review time and will be refused under H11.

## Child status

| id | child | status | order |
|----|-------|--------|-------|
| `bridge-stoa` | stoa core modules + 3 CLI commands | pending | 1 |
| `bridge-plugin` | converter skill, capabilities, emission, fixtures | pending | 2 |
