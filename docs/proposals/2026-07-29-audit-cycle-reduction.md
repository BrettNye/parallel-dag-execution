# Proposal: parallel lens auditing for specs and DAG plans

**Status:** proposal, awaiting review. Not a spec yet.
**Author:** drafted with Claude, 2026-07-29
**Target:** `parallel-dag-execution` plugin, v0.5.0 (Phase 1) / v0.6.0 (Phase 2)
**Supersedes:** first draft of this file (serial-audit framing)

---

## 0. Change surface — additive vs. modifying

**Phase 1 is purely additive.** No existing file changes except a version bump.

| File | Phase | Nature |
|------|-------|--------|
| `agents/dag-auditor.md` | 1 | **new** |
| `agents/dag-audit-reconciler.md` | 1 | **new** |
| `skills/auditing-artifacts/SKILL.md` | 1 | **new** |
| `skills/auditing-artifacts/lenses-spec.md` | 1 | **new** |
| `skills/auditing-artifacts/lenses-plan.md` | 1 | **new** |
| `skills/auditing-artifacts/auditor-prompt.md` | 1 | **new** |
| `skills/auditing-artifacts/reconciler-prompt.md` | 1 | **new** |
| `skills/auditing-artifacts/audit-charter-template.md` | 1 | **new** |
| `commands/audit-spec.md` | 1 | **new** |
| `commands/audit-plan.md` | 1 | **new** |
| `tests/fixtures/audit/**` | 1 | **new** |
| `.claude-plugin/plugin.json` | 1 | modify — version `0.4.0` → `0.5.0` only |
| `README.md` | 1 | modify — additive section: pipeline diagram + 2 commands |
| `skills/writing-dag-plans/plan-format.md` | 2 | modify — adds 2 **optional** sections (C5) |
| `skills/writing-dag-plans/SKILL.md` | 2 | modify — step 8 reclassified; consolidation task appended (C6, C8) |
| `skills/executing-dag-plans/quality-reviewer-prompt.md` | 2 | modify — scope line strengthened (C7) |
| `skills/executing-dag-plans/SKILL.md` | 2 | modify — consolidation log lifecycle (C7/C8) |

Untouched in both phases: `plan-quality.md` (H1–H11, S1–S11 all stand),
`agents/dag-{implementer,spec-reviewer,quality-reviewer,merged-reviewer}.md`
except the one C7 prompt line, `commands/{execute,plan,update}.md`, all existing
`tests/fixtures/**`.

Phase 1 is deliverable and useful alone. Nothing in it can regress an existing
plan, because nothing in it is on the existing path — the audit is invoked
explicitly at a gate.

### 0.1 As built — what implementation changed (2026-07-29)

Phase 1 shipped. This section records the deltas rather than editing the proposal
above, so the difference between what was designed and what running it taught us
stays visible. **Five flaws were found by executing the skill; none was found by
re-reading it.**

| Change | Why |
|---|---|
| Lenses write their own report files; the orchestrator only handles paths | Step 6 as designed had the orchestrator write reports **verbatim** — but they arrive in its context, so that means reproducing tens of thousands of tokens it already holds, and re-creating the pressure to summarise that "verbatim" existed to prevent. Byte-identical is now true by construction. |
| `rev` is a **normalized** hash — record section excluded, trailing blanks stripped | The original `rev <sha-or-hash>` self-invalidated: writing the record changes the file, so the artifact reads as "changed" forever, the step-3 short-circuit never fires, and every re-audit silently pays full price. |
| The audit directory is defined (`<artifact-dir>/.audit/<artifact-basename>/`) | `reconciler-prompt.md` referenced an `<audit-dir>` that nothing defined. |
| Fixtures are audited **read-only** — steps 6 and 9 skipped | Writing an `## Audit record` into a fixture rewrites the input, and some fixtures deliberately carry one to exercise the short-circuit. Running the fixtures is how anyone smoke-tests this. |
| Downstream artifacts are passed to every lens (step 2.5), and the reconciler re-checks every BLOCKING against them | Three of five proposed BLOCKINGs on a partly-implemented spec were defects a downstream plan already stated correctly — including **two lenses converging on one**, because they shared a blind spot rather than confirming each other. |
| A `coherence` lens was added to both catalogs | Every other lens compares the artifact to something *external*. Nothing compared it to itself, and long specs amended in place are exactly where that bites. |
| `charter` reclassified as **not fixture-testable** | Its job is reading a real charter and real enforcement config; a synthetic fixture would grade it against a fake repo. Validated per-repo instead. |
| The reconciler got its own fixture harness, with the grading key **outside** the case tree | Nothing graded the component carrying severity assignment, promotion, and the downgrade log — and its failures are absences, which never look wrong on the page. |

Two claims in §1 need qualifying against evidence:

- **§1.2's premise held.** Of ~18 findings raised after a first pass across two real
  audit lineages, one was genuinely undiscoverable earlier. But the payoff was **not**
  recall of known findings — it was a large volume of *net-new* blocking defects. §6
  records the numbers.
- **Convergence is weaker evidence than §2 implies.** Two lenses agreeing can be wrong
  in the same way when they share a blind spot; observed twice. Convergence multiplies
  confidence only across *independent* evidence paths, and the reconciler now carries
  that caution explicitly.

Still untested: whether a **cold session** honours "dispatch every lens in ONE
message." It cannot be checked by an orchestrator that has just been reasoning about
why parallelism matters.

---

## 1. The problem

Specs and plans take 3–4 audit rounds, and each round's *fix* generates the next
round's blocker. Findings are generally correct, so this is not model
degradation.

### 1.1 The audits are load-bearing and must not be weakened

The auditors always catch real things. The mechanism is **absent context, not
added opinion** — a fresh auditor has no commitment to the choices the author
already made, and no memory of the reasoning that made a weak choice feel
settled. That is an asset that cannot be replicated by asking the author to look
harder.

Total findings surfaced is the quality driver. **It must not go down.** The
target is the same findings in fewer serial rounds.

### 1.2 A single auditor is one draw from the lens distribution

Fresh context gives independence, but a broad "audit this" prompt gives *one*
sample of which lens the auditor happens to apply. Whether it looks hardest at
coverage, or at DAG races, or at unstated failure paths, is luck. This is why
round 3 still finds real material: it is a **new draw, not a deeper look**.

That is the actual argument for parallelism, and it is stronger than the
efficiency argument: seriality *degrades the very thing that makes the auditors
work*. Round N+1's auditor reads the document **as fixed by round N**, so it is
anchored by those fixes. Independence is maximal in parallel and decays with
every serial round.

### 1.3 Duplicated lenses masquerading as diverse ones

Diversity is the asset; duplication is the defect. The DRY/SRP/SoC criterion is
currently applied at seven points with independent authority to demand changes:

| # | Where | Form |
|---|-------|------|
| 1 | `writing-dag-plans/SKILL.md` step 8 | "Decomposition-principles audit" — DRY / SRP / SoC / repo-convention / contract clarity |
| 2 | `plan-quality.md` S1 | DRY across sibling tasks (mechanical, bounded) |
| 3 | `plan-quality.md` S6 | premature-abstraction signals (mechanical, bounded) |
| 4 | ai-os `spec-auditor.md` §6 | "Design soundness (DRY / SRP / SoC / best practice)" |
| 5 | ai-os `plan-auditor.md` §8 | near-verbatim copy of #4 |
| 6 | `dag-quality-reviewer` | per task, per plan |
| 7 | operator's ad-hoc prompt, twice per plan | "…DRY, SRP, SoC and industry standard/best practices" |

#4 and #5 are the same draw twice — that is not a second lens. #7 is a variable
string doing a job that should be a fixed artifact. The remedy is **not fewer
audits**; it is to make the lenses non-overlapping and put one reconciler above
them.

### 1.4 Two supporting mechanisms

**Fixes are scored on closing the finding, never on cost.** Nothing asks what a
fix did to the plan — tasks added, files newly in scope, edges created. Every
round is monotonically accretive, and new surface is new audit target.

**Empirical questions are answered in prose.** Does this MySQL version support
`JSON_TABLE`; is that mock stale; is this provider actually *exported* and not
merely provided. Resolving these by reasoning produces a guess; the next audit
correctly flags the guess; the fix is another guess.

### 1.5 A third mechanism: the artifact grew

Not every round is a repeated draw or sequential discovery. The overtime 3c
second audit pass states its own cause: the spec "had grown a layout section,
three copy blocks, and a list redesign" since the first pass. Six of its findings
were therefore the **first** audit of content that did not exist at round 1.

Those rounds are legitimate and unavoidable — and no amount of parallelism at
round 1 prevents them, because there was nothing to audit. But they are being run
as full-document re-reads, which is what reopens already-settled ground and
generates the churn that *looks* like the other two mechanisms.

**Consequence for the design:** a re-audit of an artifact that has changed since
its last audit is scoped to **the diff plus its dependents**, not the whole
document. See §2.6.

---

## 2. Architecture: lens fan-out + reconciler

```
                 ┌── lens 1 ──┐
   artifact ─────┼── lens 2 ──┼──► reconciler ──► verdict + classified findings
   + charter     ├── lens 3 ──┤
                 ├── … ───────┤
                 └── lens N ──┘
      (parallel, independent, each blind to the others)
```

Each lens is a fresh-context auditor with **one** assigned concern and no
authority to gate. The reconciler sees every finding at once.

The reconciler is the piece that actually kills the cycle: it resolves
*interacting* findings jointly instead of patching them serially, which is
precisely how fix N stops producing blocker N+1. It also dedupes and assigns
severity, so no individual lens can gate on an unbounded criterion.

### 2.1 Plan-audit lenses (6)

| Lens | Concern | Default tier |
|------|---------|--------------|
| `coverage` | requirement→task matrix; under-build **and** over-build | opus |
| `dag-integrity` | edges real and complete; no cycles; no shared `files:` between parallel-runnable tasks; `single_threaded` correctness | standard |
| `grounding` | every assumption checked against code; owns the grounding table and the `NOT-FOUND` rows | standard |
| `charter` | repo invariants; named per-layer reference implementations | standard |
| `context-sufficiency` | can an implementer finish each task from its body + immediate-dep context alone? | opus |
| `verifiability` | observable completion check per task; **would the stated check pass if the code threw on line 1?** | opus |
| `coherence` | contradictions **within the plan itself** — a task contradicting another, a superseded decision with no marker at the point of claim, naming drift, tables disagreeing with prose | standard |

`verifiability` earns a dedicated lens on evidence: tautological assertions,
absence-assertions that pass when the path crashes, and unpinned template
bindings are all recurring, and all invisible to the other five.

### 2.2 Spec-audit lenses (5)

| Lens | Concern | Default tier |
|------|---------|--------------|
| `absence` | unstated failure paths, boundary/empty/zero inputs, concurrency and ordering, idempotency on replay | opus |
| `ambiguity` | requirements two competent engineers would implement differently; requirements with no observable outcome | opus |
| `charter` | conflicts with repo invariants and business rules | standard |
| `grounding` | does the spec's picture of the current system match the code? | standard |
| `design` | DRY / SRP / SoC / reuse-over-reinvent — DEFERRED unless a concrete failure is named | opus |
| `coherence` | contradictions **within the spec itself** — see §2.2.1 | standard |

#### 2.2.1 The `coherence` lens, and why it is not optional

Every other lens compares the artifact to something *external* — the code, the
spec, the charter. None of them compares the artifact **to itself**. That is a
structural blind spot, and it is load-bearing in a workflow where long specs are
amended in place across several passes.

Evidenced: the third audit pass on the overtime 3c spec lineage found that §8 and
§10 still named `apps/modules/admin` and `apps/modules/overtime` as the UI
locations while the override sat ~100 lines later in §10b. The fix was an inline
`SUPERSEDED` marker at each point of claim, precisely because a reader who stops
at §8 is misled. The same pass fixed a stale line citation
(`cookie.service.ts:30`, not `:29`) — an internal-reference defect, not a
code-mismatch.

The lens hunts: incompatible statements across sections · amendments that
supersede an earlier claim without a marker at the point of claim · naming drift
(one concept under two names, or one name for two concepts) · tables and layer
maps disagreeing with their prose · cross-references to the wrong or a
nonexistent section · a stated invariant violated elsewhere in the same document
· contradictory ordering claims.

It must quote **both** conflicting passages and state which is intended, or
declare it undecidable and force the author to choose.

### 2.3 Severity taxonomy (assigned by the reconciler, not the lenses)

- **BLOCKING** — will fail, produce wrong behavior, corrupt state, or violate a
  charter invariant. Must name the concrete failure.
- **DEFERRED** — real but non-blocking. Does not gate the verdict; requires no fix.
- **EMPIRICAL-UNKNOWN** — not settleable by reading. Becomes a probe task. Never
  guessed at, never resolved in prose.
- **UNVERIFIABLE** — the lens could not ground it. Reported with what would be
  needed. Not a finding.

Design-principle observations are DEFERRED **unless** a concrete failure is
named, in which case they are BLOCKING like anything else. This keeps every lens
and removes the unbounded one's authority to gate — the single highest-leverage
change here.

"No blocking findings" is an expected, successful outcome and must be stated as
such in the agent body.

### 2.4 Grounding discipline (every lens)

- Positive claims about existing code require a `file:line` citation.
- **Negative claims require two independent search strategies**, both stated
  (symbol grep + filename/glob sweep). One grep is not evidence of absence — a
  false absence produces a fix that duplicates existing code.
- Docs and `CLAUDE.md` are **not** evidence about code; they go stale.
- Verify signatures, not just existence. Confirm a dependency is *exported*, not
  merely provided.
- Uncited findings with no named failure mode are dropped, not reported.

### 2.5 Gate separation

```
brainstorm → spec → [gate 1: audit-spec] → writing-dag-plans → [gate 2: audit-plan] → executing-dag-plans
```

Gate 2 may **not** revisit gate 1. The spec is frozen at gate 2; the plan audit
asks only *does this plan faithfully implement the approved spec, and will it
execute safely*. This removes an entire duplicated round.

### 2.6 Re-audit is diff-scoped

When an artifact is audited, the skill records the audited revision (git SHA, or a
content hash for an uncommitted file). On a subsequent audit of the same artifact:

- If unchanged → report the prior verdict; do not re-run the fan-out.
- If changed → each lens receives **the diff plus the sections that depend on it**,
  not the whole document, plus the prior audit's finding set so it does not
  re-report what was already resolved or already accepted as DEFERRED.
- Full re-audits happen only on explicit request (`--full`).

Rationale in §1.5: whole-document re-reads after a partial edit are what reopen
settled ground. This is also the mechanism that makes the `## Decisions` ledger
(C5) effective rather than advisory — a diff-scoped lens has no occasion to
revisit a decision it was not shown.

---

## 3. Implementation layout

**Two agents, one skill, two commands.** `plugin.json` declares nothing about
agents/skills/commands — discovery is by directory convention — so adding files
is the whole install story.

```
agents/dag-auditor.md              # generic; lens + artifact type arrive via prompt
agents/dag-audit-reconciler.md
skills/auditing-artifacts/
  SKILL.md                         # orchestrator: pick gate, fan out, reconcile, verdict
  lenses-spec.md                   # the 5 spec lens fragments
  lenses-plan.md                   # the 6 plan lens fragments
  auditor-prompt.md                # dispatch template
  reconciler-prompt.md
  audit-charter-template.md
commands/audit-spec.md
commands/audit-plan.md
```

### 3.1 One lens-parameterized agent, not eleven

Eleven lens agents would be near-identical files differing in one section — same
tools, same grounding rules, same severity taxonomy, same output format. That is
the duplication `plan-quality.md` S1 exists to catch. Dispatching the same
`subagent_type` N times with N different prompts is the normal pattern.

`dag-auditor.md` therefore holds only the invariant machinery: charter loading,
grounding discipline, severity taxonomy, output format, "do not perform
agreement," findings must be locatable, and the hard rule that it owns **one**
lens and must not report outside it. Adding a lens later is one row in a catalog,
not a new agent.

Consequence: subagents never self-trigger. Auto-selection by `description` is not
in play here — the skill owns dispatch, which is what makes a fixed N-way fan-out
deterministic instead of a matter of what the main loop feels like doing.

`dag-audit-reconciler.md` is a genuine second agent: it reads findings, not code,
and its output is a merged, severity-classified set with jointly-chosen
resolutions.

### 3.2 Tiering

Reuse the executor's existing `resolve_model(resolve_tier(...))` pattern. Default
tier per lens comes from the catalog (§2.1, §2.2); plan-level and per-invocation
overrides follow the conventions already in `plan-format.md`.

### 3.3 Generic plugin vs. repo-specific charter

Two layers. The ai-os auditors' best catches come from their repo-specific
sections ("the `events` table schema never changes", "per-type behavior lives on
the registration"). Genericizing those away would gut them; hardcoding them makes
the agents unshippable.

- **Plugin layer (generic):** the audit process. Zero repo knowledge.
- **Repo layer:** `.claude/audit-charter.md` — hard invariants, named per-layer
  reference implementations, recurring bug classes, frozen-decision policy. Read
  at dispatch. If absent, the auditor proceeds and states the limitation.

`crewtracks-modules/.claude/agents/convention-reviewer.md` is already this layer,
hand-written. Formalizing the split makes it data instead of a forked agent. The
charter is also the natural home for the *named* per-layer reference
implementation that `writing-dag-plans` step 8 already demands but has nowhere to
store.

Migration for ai-os: move `spec-auditor` §4 and the invariant clauses of
`plan-auditor` §6/§8 into `ai-os/.claude/audit-charter.md`; both agents then
collapse into the generic one. ai-os loses nothing.

### 3.4 Preserved verbatim from the ai-os pair

Requirement inventory → coverage matrix · under-build *and* over-build as separate
outputs · file→tasks conflict map · "absence is the most dangerous finding" ·
the testability question ("what observable behavior proves this is done?") ·
blunt READY/NOT-READY verdict · the `Looks solid` section (underrated — it tells
the author what *not* to touch, which suppresses churn) · "do not perform
agreement" · "a finding the author cannot locate is not a finding."

### 3.5 Skill vs. Workflow for the fan-out

Build as a skill: the main loop dispatches N Agent calls in one message, then the
reconciler. Consistent with how `executing-dag-plans` already dispatches.

The `Workflow` tool would make it genuinely deterministic — `parallel()` plus
schema-validated structured output, so the reconciler receives typed findings
instead of parsed markdown. Better fit long-term, but it needs explicit per-run
opt-in and it is unconfirmed whether a plugin can ship workflow scripts. Revisit
once the lens sets have settled.

---

## 4. Phase 2 (modifies existing files)

Deliberately deferred so Phase 1 ships clean.

**C5 — `plan-format.md`: two new sections.**
`## Decisions` (`DECIDED: <what> — because <why> — <date>`; challengeable only
with new grounded evidence, never with a better idea) and
`## Empirical unknowns` (each owned by a probe task; a lens flagging something
already listed here is not reporting a finding). Together these stop
re-litigation across passes.
**Ship as optional-but-recommended**, not required — making them required
invalidates every existing plan and every `tests/fixtures/**` plan fixture.

**C6 — `writing-dag-plans/SKILL.md` step 8 reclassified.** Keep every judgment
pass (prose-consumption closure, elided-sibling completeness, contract clarity,
DRY-across-plan) — drop nothing. Restate its output as DEFERRED-severity
warnings, matching what it already does, and add a pointer that `audit-plan` is
the gate and step 8 is not a second one. Wording only.

**C7 + C8 — consolidation log (must ship together).**
`quality-reviewer-prompt.md` already says "Do NOT propose unrelated refactoring —
stay within `files:`". Strengthen to: *you may not propose changes to files
outside this task's `files:` list; cross-task duplication is explicitly not your
finding — record it in the consolidation log and APPROVE if the task is otherwise
sound.*

Rationale: a quality reviewer seeing task 7 alone, judged on DRY, finds
duplication with task 3 — and the fix widens task 7's `files:` into task 3's
files. That breaks the disjointness the executor depends on and is a known source
of parallel-implementer index and branch-tip races. DRY is not evaluable at task
granularity.

C8 gives it a destination: `writing-dag-plans` appends one terminal task owning
the consolidation log — relevant files in scope, `single_threaded: true`, depends
on every leaf. Cross-cutting cleanup then happens exactly once, performed by an
agent that can see the whole picture.

---

## 5. Deliberately not proposed

- **Hard cap on audit rounds.** Trades real findings for latency and papers over
  the cause. Dropped.
- **Fix-cost budget** (every fix states `+N tasks, +N files, +N edges`;
  above-threshold fixes escalate as scope changes rather than being absorbed).
  This is the one change that genuinely reduces total findings, so it waits on
  §6 data rather than argument.

---

## 6. Evidence

### 6.1 Retroactive classification (done, 2026-07-29)

Two real audit lineages in `crewtracks-modules`, reconstructed from git:

- **Haul PUP/notes/customer** — `e46ae4d0` (spec authored) → `3256346f` (spec
  audit, 9 findings) → `dd915817` (plan authored + 4 more spec corrections) →
  `1d6974cf` (plan audit, 4 findings).
- **Overtime 3c** — spec authored, then a second audit pass (`6daeda00`, 6
  findings) and a third (`94fa8f84`, 4 findings).

Of ~18 findings raised **after** the first pass:

| Classification | Count |
|---|---|
| Discoverable at first pass by a **named lens** | ~14 |
| First audit of content that did not exist at round 1 (§1.5) | 6 (subset of above) |
| Genuinely sequential — created by an earlier fix | **1** |
| Requires a lens not previously in the set (`coherence`) | 1 |

**One finding in eighteen was genuinely undiscoverable at round 1.** The
competing hypothesis in §1.2 — that discovery is inherently sequential and
parallelism cannot help — is not supported.

**`grounding` carries the load.** Seven of the post-first-pass findings were
signature/existence checks: `notesSummary` needs no new query because
`listHauls` already selects it · the real method is `findAllLookup` with no
`exists()` · the real method is `getHaulWithEvents`, not `getHaul` ·
`canDeactivate` has zero occurrences in the app · `pEditableColumn` and row
expansion have no in-app precedent · a stale line citation · and §10b's
load-bearing auth premise cited **CLAUDE.md prose rather than code** — the
docs-are-not-evidence rule (§2.4) catching a real miss retroactively.

**The sharpest single result.** Round 1 of the haul spec quoted
`lookupEquipment`'s opts signature *and* its batch-lookup `{}` caching behavior —
it had `apps/api/src/entities/entities.service.ts:84-95` open — and round 2 then
found that adding `isPup` without extending the cache key serves and poisons the
unfiltered entry. Confirmed: the key is built from `variant` + `typeCode` +
`excludeTypeCode` at `:88-93`. Same function, same read, one inference further.
That is a new draw, not a deeper look.

**Counter-evidence worth recording.** The largest single restructure in the
dataset (`1d6974cf`: −1 task, three tasks rewired) came from a **DRY** finding —
the criterion §2.3 defaults to DEFERRED. It named a concrete drift mechanism
("two runtimes, no shared import possible"), so it classifies BLOCKING under the
taxonomy as written and the gate holds. But it is the closest call in the
proposal, and the reason §2.3's escape hatch must stay.

### 6.2 Blind retrodiction (done, 2026-07-29)

Six spec lenses run in parallel against the haul spec at `e46ae4d0` — before any
audit touched it — with the answer key withheld. Of the 15 serial findings, 13
are spec-scope (C2–C4 belong to the plan gate, which was not run).

**Recall: ~10 of 13 spec-scope findings in ONE parallel pass**, versus three
serial rounds. Several were recovered *deeper* than the original: A1 arrived with
the TS2741 construction sites and the `EntitiesLookupCacheService` shape problem
attached; B3 arrived with the 90-second TTL window quantified and the existing
key-suffix fix named.

**Net-new: ~30 distinct blocking findings** after collapsing cross-lens
duplicates — double the serial process's entire output, including a client-side-only
permission gate on an editable cell, a `modules-table` column-inference defect
that 400s the list query, and a `@crewtracks/haul` barrel that uses explicit
named re-exports (so `formatHaulNotes` would not resolve at all).

**Three misses, one lens-set gap.** A7 (`customer` → `customerName`, to
disambiguate from the existing `haul_events.customerId` supplier field) was
missed by all six. No lens owns *"does this new identifier collide with or
shadow an adjacent existing one?"* — `coherence` compares the doc to itself and
`grounding` verifies claims that were made, not names that were chosen. **Fix:
extend `grounding` to check every newly-introduced identifier against adjacent
existing identifiers in the same domain.** A8 and B4 were low-value misses (a
"no change needed" note and a method-name correction).

**Cross-lens corroboration worked.** Three independent lenses found the
cleared-edit `'' `-vs-`null` trap and three found the sheet-vs-report customer
divergence, each via a different evidence path.

**The most valuable result: two lenses reached OPPOSITE verdicts.** See §6.2.1.

#### 6.2.1 Lens disagreement, and the reconciler tiebreak rule

On the same requirement (§3's toast-`key` directive):

- `grounding` → **BLOCKING**: the haul-tracking toast host is keyless
  (`apps/modules/miller-paving/haul-tracking/src/app/app.component.html:3`), and
  the only `key="bc"` host in the repo is
  `apps/reporting/reporting-engine-ui/src/app/app.html:59`, so a message carrying
  that key is the one that gets dropped. Two search strategies stated.
- `charter` → **no finding**: "a genuine repo landmine, and the spec is on the
  right side of it," citing only that the existing `messageService.add` calls are
  keyless.

`grounding` is correct — independently confirmed. `charter` observed the call
sites and never checked the **host**, which is the component that actually
filters by key. Both cited real code; one had an incomplete evidence chain.

This is not a defect in the fan-out — it is the reason a reconciler must exist,
and it fixes the reconciler's contract:

1. Contradictory lens verdicts are **surfaced explicitly**, never silently
   resolved by majority. One lens with a complete evidence chain beats five
   without.
2. The tiebreak is **evidence completeness, not lens count**: which verdict
   traced the full mechanism (producer *and* consumer, writer *and* reader,
   caller *and* host)?
3. A "no finding" from a lens is itself a claim, and is subject to the same
   grounding rules as a finding. `charter`'s clean bill of health was the wrong
   answer, delivered confidently.

**Also validated:** `charter` checked `eslint.config.mjs:17-29` and found
`depConstraints` set to `'*' / ['*']` — ring boundaries are NOT lint-enforced in
this repo — and therefore graded every layering deviation DEFERRED rather than
BLOCKING. That is the severity gate working from verified enforcement rather than
assumed CI. `design` likewise returned 1 BLOCKING / 5 DEFERRED with an explicit
"no concrete failure" annotation on each deferral.

### 6.3 Forward metrics

Instrument the next 2–3 plans. Tag every finding with round number,
`CORRECTNESS | AESTHETIC`, and whether execution would actually have failed
without the fix.

- Primary: **rounds-to-ready at constant-or-higher total BLOCKING findings.**
  Total findings going down is a regression, not a win.
- If round 3+ is predominantly AESTHETIC → the severity gate is working;
  consider adopting the fix budget (§5).
- If round 3+ still catches CORRECTNESS → **add a lens, not a round.**

---

## 7. Rollout

**Phase 1 (v0.5.0) — additive only**
1. `dag-auditor.md` + `dag-audit-reconciler.md`.
2. `skills/auditing-artifacts/**` incl. both lens catalogs and the charter template.
3. `commands/audit-spec.md`, `commands/audit-plan.md`.
4. `tests/fixtures/audit/**` — should-flag / should-pass artifacts per lens,
   following the existing `should-pass` / `should-warn` / `should-refuse` layout.
5. README pipeline section; version bump.
6. Author `crewtracks-modules/.claude/audit-charter.md` and migrate ai-os's
   invariants out of its two agents.

**Phase 2 (v0.6.0) — modifies existing**
7. C5 (optional sections) + C6 (wording).
8. C7 + C8 together, with their own fixtures.

---

## 8. Open questions

1. **Lens sets** (§2.1, §2.2) — sign-off needed before building; everything else
   is downstream of these. Six + five, or fold `charter` into `grounding`?
2. **Charter location** — `.claude/audit-charter.md`, or a pointer file into what
   the repo already maintains (crewtracks has `docs/conventions/*` + `docs/map.md`)?
   A pointer is less likely to go stale; a standalone file is portable.
3. **Charter absent** — proceed with a stated limitation (proposed), or refuse?
4. **Does the `-stoa` variant inherit this**, or need its own port?
5. **Reconciler authority** — may it *reject* a lens finding outright, or only
   downgrade its severity? Rejection is more useful and more dangerous.
