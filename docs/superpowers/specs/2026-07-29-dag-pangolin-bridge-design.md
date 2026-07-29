# DAG plan → Pangolin orch bridge + follow-up lane

**Created:** 2026-07-29
**Status:** design — approved, pending implementation plan
**Spans:** `BrettNye/parallel-dag-execution` (MIT) and `BrettNye/stoa` (FSL-1.1-MIT). `QuarrySystems/pangolin` (BUSL-1.1) is **not modified**.

---

## 1. Mission

Close this loop unattended:

```
DAG plan (authored + audited in-session, unchanged)
  → plan.json
  → pangolin orch submit
  → implementers surface out-of-scope concerns
  → concerns captured as stoa tasks (four-section format)
  → materialized into follow-up plan.json (impl + verify pairs)
  → pangolin orch submit
  → morning: reviewable patches + verified audit bundle
```

Everything new is a skill in the plugin or a command in stoa. Pangolin gains
nothing — the follow-up "pattern" turns out to be plan.json configuration over
the shipped `pipeline` pattern, not new orchestrator code (§5.2).

All file:line citations below were verified against `QuarrySystems/pangolin`
`main` @ `#105` (local checkout `C:\Users\brett\Documents\Knowledge\agora`),
`BrettNye/stoa` @ `7c1950d`, and this repo @ `8548dab`.

---

## 2. Non-goals

- No new repo. No pangolin source changes. No work at pangolin's repo root.
- Do not rebuild claiming, locking, or task state — all three exist.
- Do not port the plugin's two-stage review chain into either lane (§10).
- Do not build a stoa-backed `Trigger`. Not viable anyway — see §3.4.
- No `force` path in the materializer. The readiness gate is a precondition.
- No orchestration abstraction spanning all three repos.

---

## 3. Verified preconditions

These are load-bearing facts, not assumptions. If any stops holding, the design
breaks in a specific named way.

### 3.1 Every dispatch gets a fresh workspace

The worker overlays into a fresh `mkdtemp` directory
(`pangolin-worker/src/entrypoint.ts:355-357`). `needs` products are
materialized as **inert files** at `inputs/<key>` (`:385`) — nothing applies
them. Building on upstream work is "a **pack/setup concern**, not the generic
seam" (`docs/superpowers/specs/2026-06-04-agora-typed-product-handoff-design.md:264`;
restated in `docs-site/.../reference/plan-json.md:83-84`).

**Consequence:** `depends_on` is not portable. A downstream task sees a clean
checkout unless its ancestors' patches are bound *and* applied. This drives the
closure algorithm (§6.2).

### 3.2 Plugin rule 4 (file-disjoint parallel branches) is a hard dependency

`skills/writing-dag-plans/plan-format.md:229` requires that two tasks sharing a
`files:` entry have a directed path between them. This is exactly the property
that makes ancestor patches compose: any two patches in a closure are either
chain-ordered (topological order reproduces the state each was diffed against)
or file-disjoint (they commute). Every pair is one case or the other.

**If rule 4 is ever relaxed, the converter breaks.** Named here so the coupling
is explicit.

### 3.3 Local `file://` storage only (v1)

Harvest resolves refs by string transform:
`pangolin://<ns>/<type>/<name>/<hash>` → `<root>/<ns>/<type>/<name>/<hash>.blob`
(`pangolin-storage-local/src/index.ts:6-7`, implemented at `:401`). There is no
CLI verb that fetches bytes by ref — the CLI surface is
`capabilities | subagent | env | dispatch | deploy | orch | verify | pipeline`
(`pangolin-cli/src/index.ts:35-42`). S3-backed storage breaks this transform and
would require a client-linked harvester (and a BUSL dependency in stoa), so v1 is
local-only.

### 3.4 The `Trigger` seam cannot schedule runs

`Trigger` is `{ id, initialReady(run): string[] }`
(`pangolin-orchestrator/src/contracts/trigger.ts`) — it selects which items of an
*already-submitted* run start ready, is called once at submit
(`orchestrator.ts:160-161, 196`), and never sees the store. It cannot create runs.

`pangolin orch schedule` is also unusable for the materializer: it parses
`plan.json` once at registration and stores the object on the `Schedule`
(`cmd-orch.ts:367-375`), then resubmits it verbatim each firing
(`cron-scheduler.ts:21`). It would replay last night's plan forever.

**Consequence:** the materializer runs under an OS-level scheduler that
regenerates plans and calls `orch submit`.

### 3.5 `pangolin-setup.sh` is a single-slot, last-write-wins file

`ClaudeCodeProvider` deliberately generates none, because "synthesizing one per
capability would collide on multi-capability dispatches — only the last would
actually run" (`pangolin-cli/src/providers/claude-code.ts:15-18`).

**Consequence:** exactly one capability per dispatch may ship a setup script, and
it must be **static** — one script correct for every item on its lane (§6.2).

---

## 4. What Phase 0 corrected

Four premises in the original brief were wrong. Recorded so they are not
reintroduced.

| Premise | Reality |
|---|---|
| Reviewers surface out-of-scope findings | They are forbidden to. Spec reviewer files over-build as an ISSUE to remove (`spec-reviewer-prompt.md:33-34`); quality reviewer is told "Do NOT propose unrelated refactoring — stay within `files:`" (`quality-reviewer-prompt.md:40`). The only observation channel is the implementer's `DONE_WITH_CONCERNS` (`agents/dag-implementer.md:32`), which the executor discards: "log and proceed" (`skills/executing-dag-plans/SKILL.md:71`). |
| `files` → `resourceLocks` is a shape match | Shape matches; semantics don't. `selectRunnable` matches lock keys by exact `Set` membership (`engine/lock-manager.ts:12`). No glob expansion — `src/**/*.ts` and `src/foo.ts` never contend. |
| The `handoff` check proves the verifier consumed the implementer's patch | Weaker. `checkHandoffClosure` proves each `inputRefs` entry was produced by **some** `done` item in the same run (`pangolin-core/src/audit-verify-bundle.ts:182-207`) — not by the specific `needs` upstream — and returns `ok: true, detail: 'no handoff edges'` on a zero-`needs` plan (`:204-205`). |
| The plugin repo is 100% shell | 84 `.md`, 2 `.sh`, 3 `.json`. It is a prompt repo with no build or runtime. |

Two further corrections:

- **`target` / `workerImage` / `secrets` are executor config, not per-item.**
  `plan-json.md:233-242`; enforced at `executors/dispatch.ts:11-23`.
- **`orch validate` is a graph check, not a dispatchability check.** It runs
  without a `PackRegistry` (`cmd-orch.ts:128`) and never verifies
  `inputs.subagent`, the field `DispatchExecutor.fire` throws on
  (`dispatch.ts:52-56`). A plan can validate clean and fail at dispatch (§11).

---

## 5. Architecture

### 5.1 Two lanes

```
LANE A — main run
  <plan>-dag.md ──/to-plan-json──▶ plan.json (queue: "dag")
                                        │ orch submit
                                        ▼
                        N impl containers + 1 terminal verify
                                        │ orch audit --out bundle.json
                                        ▼
                     patches/*.patch + concerns blobs + bundle.json

HARVEST   stoa task-import --from-bundle bundle.json --storage-root <dir>
                                        ▼
                        stoa backlog (type: task, status: pending)

LANE B — follow-ups (OS cron; one run per task)
  stoa task-materialize --out-dir plans/ ──▶ plan-<id>.json (queue: "followups")
                                        │ orch submit (one per file)
                                        ▼
                        impl ──patch──▶ verify (inputs.gate, maxFixAttempts: 1)
                                        ▼
  stoa task-close --from-bundle <bundle> --task-id <id>
```

### 5.2 Two queues — required, not stylistic

Lane A **must not** sit on a `pipeline`-bound queue. `pipeline.plan()` rewrites
every item at index > 0 whose `depends_on` is empty to depend on its predecessor
(`patterns/pipeline.ts:11-18`), and it runs **before** `normalizeRun`
(`orchestrator.ts:162-167`). A lane-A plan has many independent roots with
`depends_on: []`; on a pipeline queue they silently serialize into one chain —
and a red item would then cascade every later task into its respawn lineage
(`respawn.ts:42-59`).

| Queue | Pattern | Why |
|---|---|---|
| `dag` | **none** | Lane A needs no spawn. `submitRun` handles an unbound queue (`orchestrator.ts:165`); `applyPatternPhase` returns early (`:279-280`). |
| `followups` | `pipeline` | Supplies the gate. Two authored items per run, where `plan()`'s chaining coincides with the wanted `impl → verify` edge. |

Operator config: two `QueueConfig` entries (`orchestrator.ts:37-40`) in
`pangolin.config.mjs`. Not a code change.

### 5.3 One run per follow-up

Follow-ups are independent; bundling them means one red verify cascades every
later follow-up into its respawn lineage. Separate runs give failure isolation
and a per-follow-up audit bundle. Lock safety survives because `resourceLocks`
are deliberately not namespaced — "cross-run locks are intentional"
(`orchestrator.ts:190`) — and `selectRunnable` is fed an unfiltered
`store.heldLockKeys()` (`engine/tick.ts:152`).

### 5.4 Lane A has no gate

Self-gating is unsound. `buildLineage` sets `S.set(gate.id, gateCopyId)`
(`respawn.ts:73-77`); the caller then sets `S.set(config.subject, fixId)`
(`:175`). When `subject === gate.id` the second write clobbers the first, so
skipped descendants remap to the **fix** rather than the **gate copy** and
downstream resumes without re-verifying. A real gate therefore costs a second
container per task. Lane A reports; lane B gates.

---

## 6. Component 1 — converter skill (plugin)

**Location:** `skills/writing-dag-plans/` sibling, new skill
`to-plan-json` (markdown). Reads this repo's own plan format; the repo is
markdown, so the converter is a skill, not a script.

### 6.1 Input / output

Input: `docs/superpowers/plans/YYYY-MM-DD-<topic>-dag.md` per
`skills/writing-dag-plans/plan-format.md`. Output: a single `plan.json`.

### 6.2 Ancestor closure

For each task `T`: compute the transitive `depends_on` ancestor set,
topologically sort it, and bind each ancestor as a `needs` key prefixed with a
zero-padded index.

```json
{
  "id": "task-3",
  "executor": "dispatch",
  "inputs": {
    "subagent": "dag-implementer",
    "workerInput": { "instructions": "<task body verbatim>", "files": ["src/c.ts"] }
  },
  "depends_on": [],
  "resourceLocks": ["src/c.ts"],
  "needs": {
    "01-task-1": { "from": "task-1", "select": { "kind": "patch" } },
    "02-task-2": { "from": "task-2", "select": { "kind": "patch" } }
  }
}
```

`depends_on` stays `[]`; `normalizeRun` unions every `needs[*].from` at submit
(`engine/run-validator.ts:5-15`) — the same style as `handoff-dag`
(`plan-json.md:195-197`). Keys land at `inputs/<key>` (`entrypoint.ts:385`) and
satisfy the worker's traversal guard (`:374-382`).

The numbering makes **one static setup capability** correct for every item,
satisfying §3.5:

```sh
#!/bin/sh
set -e
git init -q
for f in inputs/[0-9][0-9]-*; do
  [ -e "$f" ] || continue
  git apply "$f"
done
```

Soundness: lexicographic glob order = topological order by construction; chain
pairs apply in dependency order, sibling pairs commute by rule 4 (§3.2).

### 6.3 Field mapping

| DAG plan | plan.json | Notes |
|---|---|---|
| `id` | `items[].id` | verbatim |
| `depends_on` | `needs` keys (transitive closure); `depends_on: []` | §6.2 |
| `files` | `resourceLocks` | **verbatim — no rewriting** |
| task body | `inputs.workerInput.instructions` | verbatim |
| `implementer` | `inputs.subagent` | default `dag-implementer` |
| `model_hint` | `inputs.subagent` **variant** | see §6.4 |
| `single_threaded: true` | `resourceLocks: ["_serial"]` | shared key forces serialization |
| `status` | — | dropped; pangolin owns run state |
| `review_mode`, `*_reviewer_hint` | — | dropped; no reviewers in lane A (§10) |

Locks are copied **verbatim — the converter validates, it never rewrites.**

Both lanes' lock strings must be byte-identical for cross-lane serialization to
work (§9.6), but asking a markdown skill to *transform* strings is exactly where
drift would enter. So the converter **detects** instead: before emitting, it
checks every `files:` entry against the canonical form (§8.2 step 4) — no
leading `./`, forward slashes only, no repeated slashes, no trailing slash, no
glob metacharacters — and **refuses to convert the plan** if any entry deviates,
naming the task and the offending path. Detect-and-refuse is LLM-safe in a way
that transform-and-hope is not.

The canonical form is therefore defined in exactly one place — the stoa function
in §8.2, which is unit-tested (§11.1) — and the converter is a consumer of that
definition, not a second implementation of it. Authors fix the plan; the skill
never silently changes what a task declared it would touch.

### 6.4 `model_hint` maps to a subagent variant

`DispatchExecutor` resolves the model solely from the registered subagent's def
blob, falling back to the executor's `defaultModel`
(`dispatch.ts:86, 239-253`). There is no per-item model input. So `model_hint`
selects among `dag-implementer-cheap` / `-standard` / `-opus` — three
registrations of the same body with different frontmatter `model:`.

### 6.5 Terminal verify item

One per run, binding every task's patch under the same numbering:

```json
{
  "id": "_composed-verify",
  "executor": "dispatch",
  "inputs": { "subagent": "composed-verify", "pipeline": "<registered ref>" },
  "depends_on": [],
  "resourceLocks": [],
  "needs": { "01-task-1": {"from":"task-1","select":{"kind":"patch"}}, "…": {} }
}
```

with a registered single-block pipeline:

```json
{ "schemaVersion": 1, "id": "dag.composed-verify",
  "blocks": [{ "kind": "script", "command": "<repo test cmd>", "lens": "verify" }] }
```

`lens: 'verify'` is report-only (`pangolin-core/src/pipeline.ts:20-22`), so a
failing suite yields `done` + `verify.passed === false` rather than `failed` —
keeping `failed` to mean "infrastructure broke". An agent-less pipeline is legal
(`validatePipelineSpec` requires only a non-empty block list,
`pipeline.ts:94-96`) and costs no LLM call. `inputs.subagent` is still required
by the executor (`dispatch.ts:52-56`), hence the placeholder `composed-verify`
registration.

**Rationale.** Each impl container tests only its own ancestor closure. Without
this item, "all N patches apply together and the suite passes" is never checked
anywhere until a human tries it by hand.

**Empirical check required before relying on this** (§11.3): that the worker runs
an agent-less pipeline cleanly and tolerates a placeholder subagent. Fallback if
not: a trivial agent instructed to do nothing plus a subagent-level
`VerifyConfig` — same signal, one LLM call.

---

## 7. Component 2 — implementer emission (plugin)

**Location:** `agents/dag-implementer.md`.

The implementer gains one instruction: when it has concerns, write them to
**`outputs/concerns`** — *no file extension*. `outputRefs` keys are literal
paths (`dispatch.ts:227`); dogfood's plan warns in-line that `findings.json`
"would silently break" the binding (`examples/dogfood-gated/plan.json:23`).

```json
[{ "title": "Split oversized scope-hash module",
   "files": ["src/core/scope-hash.ts"],
   "scope": "…",
   "out_of_scope": "…",
   "verification": "…" }]
```

Two rules preserve the gate's integrity:

- Write the file **only if** there is at least one concern. Absent
  `outputRefs.concerns` is the normal case.
- A concern that cannot be honestly expressed in four sections is **not**
  written. It stays prose in the report as a note for the human.

**Why the implementer and not a reviewer.** A reviewer able to route a finding
to a follow-up queue gains an escape valve on hard pass/fail calls — "real
problem, but I'll defer it" is how a quality gate rots. The implementer does not
render the verdict, so its deferrals cannot weaken the gate. Cost: the
implementer's self-assessment is lower quality and biased toward "fine".
Acceptable for a lane that is verified downstream and human-reviewed in the
morning. If the feed proves too thin after a few runs, the next move is adding
an out-of-scope section to the **spec** reviewer — the one whose over-build
findings are closest in kind. Not before.

Default (non-pipeline) execution already captures `outputs/`; dogfood-gated
relies on exactly this with no `inputs.pipeline` and receives
`outputRefs['findings']`. No pipeline is needed on lane A impl items.

### 7.1 Unattended-mode addendum

The pangolin-registered variants additionally instruct: **never write a
`needs_input` sentinel.** In an unattended lane nobody can answer. Missing
context must surface as a loud failure — write `outputs/blocked` and exit
non-zero — not a pause. This deliberately inverts `agents/dag-implementer.md:21`,
which is correct in-session and wrong here (§9.1).

---

## 8. Components 3–5 — stoa commands

All three land in `src/cli/commands/`, registered in `src/cli/index.ts`
following the existing `registerX(p: Command)` convention (`index.ts:85-86`).
They share one four-section contract and one canonicalization function.

Stoa gains knowledge of pangolin's **bundle shape and blob layout** — a coupling
to a format, not a dependency on code. This mirrors pangolin's own
`StoaProvider`, which reads stoa's on-disk convention without importing stoa
(`pangolin-cli/src/providers/stoa.ts:1-14`). Symmetric, and already sanctioned
in this ecosystem. Note stoa is `@stoa-mcp/cli`, a direct hit on pangolin's
forbidden-dependency prefix list (`scripts/check-dep-allowlist.mjs:30-35`) — the
coupling must stay one-directional and format-only.

### 8.1 `stoa task-import --from-bundle <file> --storage-root <dir>`

1. Parse bundle → items with `outputRefs` (present in the audit export,
   `orchestrator.ts:474-482`).
2. For each `done` item carrying `outputRefs.concerns`, resolve via the §3.3
   transform, read, parse.
3. Render the four-section body; run stoa's **own** `checkTaskReadiness(body)`
   (`src/core/task-readiness.ts:40`) — imported, never reimplemented. Failures
   are skipped and reported, never forced.
4. Idempotency: `findTaskOnDisk(vaultPath, id)` (`src/core/tasks.ts:278`) — same
   title → same slug → same id → skip with a report line.
5. Pass each concern's `files` array through the **same** canonicalization
   function the materializer uses (§8.2 step 4) — it is idempotent, so applying
   it at both boundaries is safe and guarantees the string stoa stores is
   already the string that becomes a lock key. Reject glob metacharacters here
   too: failing at import points at the emitting implementer, which is where the
   fix belongs, rather than surfacing a night later at materialize time.
6. `createTask` with `segregation: <canonical literal paths>` and the rendered
   body.

**Upstream change:** add optional `body?: string` to `CreateTaskInput`, with
`body: input.body ?? input.description ?? <template>` (`src/core/tasks.ts:113-122,
163`). Today `description` is overloaded — it becomes both the frontmatter field
and the whole page body (`:153, :163`), so passing a four-section body would
stuff it into frontmatter. Backward compatible.

### 8.2 `stoa task-materialize --out-dir <dir>`

One plan.json per ready pending task.

1. `listTasks({ status: 'pending' })` (`src/core/tasks.ts:206`).
2. `checkTaskReadiness(body)` — skip + report missing signals. **No force
   path.**
3. **Reject globs.** Any `segregation` entry containing `*`, `?`, or `[` skips
   the task with an explicit message. Because locks match by exact `Set`
   membership (`lock-manager.ts:12`), a glob is a lock that *silently never
   contends* — indistinguishable from a working lock until two patches collide.
   Refusing pushes the burden onto the emitter, which knows the literal paths.
4. Canonicalize survivors through one function: strip leading `./`,
   backslash→slash, collapse repeated slashes, no trailing slash.
5. Emit:

```json
{ "id": "followup-<task-id>-<date>", "queue": "followups",
  "items": [
    { "id": "impl", "executor": "dispatch",
      "inputs": { "subagent": "follow-up-implementer",
                  "workerInput": { "instructions": "<Scope + Out of scope>" } },
      "depends_on": [], "resourceLocks": ["src/core/scope-hash.ts"] },
    { "id": "verify", "executor": "dispatch",
      "inputs": { "subagent": "follow-up-verifier",
                  "workerInput": { "instructions": "<Verification>" },
                  "gate": { "onRed": "spawn-fix", "subject": "impl",
                            "maxFixAttempts": 1,
                            "fixTemplate": {
                              "executor": "dispatch",
                              "inputs": { "subagent": "follow-up-fixer" },
                              "resourceLocks": ["src/core/scope-hash.ts"] } } },
      "depends_on": [], "resourceLocks": [],
      "needs": { "work": { "from": "impl", "select": { "kind": "patch" } } } } ] }
```

**The key must be `work`.** `respawnLineage` hardcodes `fixNeeds.work`
(`respawn.ts:178-180`), so the spawned fix receives the patch under that name
regardless of what the authored item used. Any other key means verifier and fix
read different paths.

**Lane B needs its own setup capability** — `git init -q && git apply inputs/work`,
matching `examples/handoff-dag/src/capabilities.ts:15` — distinct from lane A's
numbered-closure script (§6.2). Two capabilities, each bound to its lane's
subagents.

The verifier writes `outputs/findings` on failure and carries
`VerifyConfig.command = test ! -s outputs/findings`, exactly dogfood's mechanism
(`examples/dogfood-gated/src/index.ts:13`). This yields done-but-red, the only
path that hands structured findings to the fixer (`respawn.ts:184-185`); a hard
`failed` supplies only a reason string (`:186-188`).

### 8.3 `stoa task-close --from-bundle <file> --task-id <id>`

Reads the follow-up run's terminal states, decides `completed` vs `failed`,
pulls the verifier's findings blob for `--notes`, and performs the OCC update
(`src/cli/commands/task-update.ts:9-14`; `--expected-updated` read immediately
prior). This is what makes DoD item 7 land rather than evaporate.

---

## 9. Failure semantics

### 9.1 `needs_input` — the worst mode, handled in three places

A `needs_input` sentinel makes the worker exit **0**
(`docker/pangolin-worker/bin/pangolin-worker-entry.mjs:10`) while writing **zero**
output sentinel (`pangolin-worker/test/pipeline-golden.test.ts:499`). So
`reconcile` maps it to `done` (`dispatch.ts:172`) with no `resultRef`, no
`verify`, no `outputRefs`. Downstream then fails at
`unresolved needs '<k>': upstream '<id>' has no such product`
(`engine/needs-resolver.ts:20` → `engine/tick.ts:160-165`). Falsely green
upstream; blame lands downstream. There is no orchestrator-level resume —
recovery is a fresh dispatch carrying `partial_state`
(`test/e2e/needs-input-roundtrip.test.ts:29`), client-level only.

1. **Prevent** — §7.1 instruction: never pause; fail loudly.
2. **Detect** — `done` **with no `resultRef`** is its own reported outcome class,
   *PAUSED / no product*, never folded into "done". Pure read of the audit
   export (`orchestrator.ts:474-482`).
3. **Re-attribute** — a downstream failure whose `reason` matches
   `unresolved needs '<k>': upstream '<id>'` is reported against `<id>`, with
   the downstream listed as collateral.

### 9.2 Verify fails (lane B)

Done-but-red spawns `[fix, verify~2]` (`respawn.ts:221`); the fix consumes the
impl patch plus `outputs/findings`. On a second red, `parseAttempt('verify~2')`
yields attempt 2, exceeding `maxFixAttempts: 1`, so `respawnLineage` returns `[]`
(`:154-156`) and the run seals. `stoa task-close` writes `failed` with the
verifier's notes. This path **is** DoD item 7 — it falls out of the mechanism.

### 9.3 Worker dies or hangs

The engine force-fails past `maxRuntimeMs` (default 2h, `orchestrator.ts:99`),
releasing locks so a hung dispatch cannot hold them indefinitely, then cascades
downstream to `skipped`. `maxAttempts` defaults to 2 (`:98`) — one retry, at the
same model (unlike the plugin's BLOCKED-with-upgrade, `SKILL.md:73`). Long lane-A
tasks may need `maxRuntimeMs` raised; operator config.

### 9.4 Materializer hits an unready task

Skip, report which of the four signals are missing, leave `pending`. It
resurfaces every night until the operator fixes or deletes it. Deliberately not
automated away.

### 9.5 Harvest of a partly-failed run

Only `done` items carry `outputRefs`. A wholly-failed run yields zero tasks —
correct, not an error.

### 9.6 Cross-lane lock safety

A lane-B follow-up touching a file a lane-A task is editing serializes behind it
(§5.3). This holds **only if both lanes' lock strings are byte-identical**.
Two mechanisms enforce it from opposite ends: lane B canonicalizes through one
tested function (§8.2 step 4, §11.1), and lane A refuses to convert a plan whose
`files:` entries are not already in that form (§6.3). Neither lane transforms
silently.

---

## 10. Fidelity deliberately lost

Listed so nobody later mistakes these for bugs.

| In-session | Lane A | Why |
|---|---|---|
| spec + quality review per task, unbounded fix loop | none | Morning human review is a required step and catches spec-compliance better; a gate costs 2N containers (§5.4). The implementer's TDD + `verification-before-completion` (`agents/dag-implementer.md:6, 24`) survives intact and is the real gate. |
| BLOCKED → retry with upgraded model | retry at same model | `maxAttempts: 2` (`orchestrator.ts:98`); no per-item model input (§6.4). |
| `NEEDS_CONTEXT` → controller supplies context | loud failure | Nobody to ask (§7.1). |
| per-task `review_mode` / reviewer tiers | dropped | No reviewers in lane A. |

---

## 11. Testing

### 11.1 stoa (vitest, beside the commands per `task-update.test.ts`)

- **Canonicalization byte-identity** — equivalent spellings (`./src/a.ts`,
  `src//a.ts`, `src\a.ts`) produce byte-identical lock strings. This is the
  guard against the silent-no-contention failure (§8.2 step 3).
- Glob entries rejected with the offending entry named.
- Unready tasks skipped, with the correct missing-signal list.
- Re-import is idempotent (no duplicate tasks).
- Emitted plan.json snapshot: `needs.work` key, gate block, `maxFixAttempts: 1`.

### 11.2 converter (plugin)

Fixture plans → expected plan.json under the existing `tests/*.md` LLM-graded
convention, plus two **mechanical** assertions needing no grader:

- `pangolin orch validate <out>` exits 0.
- **Every item has a non-empty `inputs.subagent`.** Required because
  `orch validate` never checks it (runs without packs, `cmd-orch.ts:128`) while
  `DispatchExecutor.fire` throws on it (`dispatch.ts:52-56`) — a plan can
  validate clean and fail at dispatch.
- Closure correctness: for a 4-task diamond, task-4's `needs` contains all three
  ancestors in topological order with correct zero-padded prefixes.
- **Refusal fixture:** a plan with a non-canonical `files:` entry (`./src/a.ts`)
  or a glob (`src/**/*.ts`) is refused, naming the task and the path — not
  silently rewritten (§6.3).

### 11.3 Empirical checks before relying on them

- Agent-less pipeline runs cleanly with a placeholder subagent (§6.5).
- `outputs/` capture works on a default (non-pipeline) dispatch for a
  no-extension filename.

---

## 12. Definition of done

1. A DAG plan converts to a valid `plan.json`; `orch validate` passes **and**
   every item carries `inputs.subagent`.
2. `orch submit` runs it; patches come back.
3. At least one implementer concern lands as a well-formed stoa task.
4. The materializer turns pending stoa tasks into follow-up plan.json files.
5. That run produces patches **and** a verify stage that executed the task's
   stated criteria.
6. `pangolin verify` on the bundle shows the `handoff` check passing **with a
   non-zero edge count** — the boolean alone is vacuous (§4).
7. A deliberately-broken follow-up fails verification, retries once, and lands
   as `failed` on the stoa task with the verifier's notes.

Item 7 is constructed on purpose — a follow-up whose `verification` section
cannot pass — so the retry-once-then-`failed` path is exercised, not assumed.

**Documentation restraint:** no README may claim the handoff check proves more
than "every consumed ref was produced by a `done` item in the same run" until
that has been verified end to end.

---

## 13. Morning view

```
RUN dag-2026-07-29        composed suite: FAILED
  task-1  done    patch ✓  verify ✓
  task-2  PAUSED  no product                     ← needs_input (§9.1)
  task-3  failed  unresolved needs → caused by task-2
  task-4  done    patch ✓  verify ✗
  concerns harvested: 3 → stoa (1 skipped: missing `verification`)
  handoff: ok — 9 input refs accounted for

FOLLOW-UPS (3 runs)
  task-split-scope-hash    completed  patch ✓
  task-thin-coverage       failed     verify red ×2 → notes written to stoa
  task-magic-number        completed  patch ✓ (after 1 fix)
```

---

## 14. One-time operator setup

1. Two `QueueConfig` entries in `pangolin.config.mjs`: `dag` (no pattern),
   `followups` (`pattern: pipeline`) — §5.2.
2. `pangolin subagent sync --provider claude-code --from <plugin>/agents`.
   The plugin's agent files already carry `name:` / `model:` frontmatter, which
   `ClaudeCodeProvider` reads directly (`providers/claude-code.ts:39-45`).
3. **Bind capabilities explicitly via `pangolin subagent register`.** `sync` does
   **not** bind them — `ClaudeCodeProvider` builds `{name, systemPrompt, model}`
   only (`:43-44`); only `StoaProvider` populates `capabilities`
   (`providers/stoa.ts:68-72`). Unbound capabilities mean patches are never
   applied, silently.
4. Register the two setup capabilities (`apply-closure`, `apply-work`) and the
   `dag.composed-verify` pipeline.
5. Register `dag-implementer-{cheap,standard,opus}`, `composed-verify`, and
   `follow-up-{implementer,verifier,fixer}`.
6. Base repo content must reach the fresh workspace — baked into `workerImage`
   or shipped as a seed capability (§3.1).
7. OS-level cron for the materializer (§3.4).

---

## 15. Open risks

- **Agent-less pipeline** unproven in this repo's examples (§6.5). Fallback
  documented.
- **Concern feed quality** — implementer self-assessment is biased toward
  "fine". Mitigation is observation over a few runs, then escalate to the spec
  reviewer if thin (§7).
- **S3 storage** would invalidate the harvest transform (§3.3).
- **Rule 4 relaxation** would break closure composition (§3.2).
