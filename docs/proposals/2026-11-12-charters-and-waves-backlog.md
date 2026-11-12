# Backlog: charters and checkpoint waves

**Status:** backlog of proposals, not a spec. Nothing here is decided or built.
**Drafted:** 2026-11-12, with Claude, from a read of seven charters written with this plugin in
one consuming repo, and of that repo's proposed checkpoint-wave trial.
**Target:** `parallel-dag-execution` plugin.

This file holds ideas and the evidence for them. It holds no task state: when an item is picked
up, it becomes a tracked task and a spec.

## Why

A spec is split in two ways, at two grains:

- **Charter → plans.** Each child has its own spec, gates and owner. Guided today by the fan-out
  checkpoint in `writing-dag-plans` and the 34-line `superspec-charter.md` template.
- **Plan → wave MRs.** One plan and one gate 2, cut into several MRs so review starts while the
  plan is still running. Not in the plugin; on trial in a consuming repo.

The two meet where a charter says "child B may start once part of child A has merged". That part
is a wave. Today the sentence is prose and nothing checks it.

## A. Can be done now (does not depend on the wave trial)

### A1. Template: describe both kinds of charter
- **Evidence:** of seven charters, five follow the template's headings. Two were written during
  design, before any spec existed, and share none of its shape: they run to 600 and 1,000 lines
  and carry per-child scope and design decisions. The template only describes the kind written
  at planning time over one approved spec.
- **Proposal:** name two kinds. A *delivery charter* (thin, over an approved spec; today's
  template). A *design charter* (written when a brainstorm finds several projects; it owns the
  decomposition and the cross-child decisions, and each child still gets its own spec).

### A2. A design-time entry point
- **Evidence:** the upstream brainstorming skill has no charter concept. Its only guidance is to
  split independent projects and brainstorm them one at a time, so decomposition, contracts and
  order get decided in a skill that never loads the template.
- **Proposal:** a command or a short skill that writes a design charter from the template when a
  brainstorm reports several projects. The upstream skill is not ours to change.

### A3. Template fields the charters had to invent
- **Evidence:** every charter added a plan link per child. Several added "accepted partial
  state" prose, partial dependencies ("B needs only two pieces of A"), a named owner for each
  contract, a "do not re-litigate" decision list, and a governance-gaps section.
- **Proposal:** child table columns `plan`, `owner`, `depends on`, `ships alone` (yes / held
  until X / dark). A contracts section where each contract names the one child that owns it.
  Optional sections for frozen decisions and open gaps.

### A4. Frontmatter that a status board can read
- **Evidence:** the template emits `id`, `title`, `type: superspec-charter`, `created`. The
  consuming repo's generated status board needs `kind`, `state` and `children:`, and its plans
  carry `parent:` and `child:` by local convention. The plan format has neither field.
- **Proposal:** add `children:` to the charter template and optional `parent:` / `child:` to
  the plan format. Keep the names configurable or documented, since the board is the repo's.

### A5. "One child at a time" no longer matches use
- **Evidence:** the skill says to pull children one at a time. Five of seven charters run
  children in parallel; one runs five at once.
- **Proposal:** "run children in parallel where the contracts allow; a child starts when the
  contracts it consumes have merged".

### A6. Child status: derived, not typed
- **Evidence:** the template calls the child status table "the single source of truth". In
  practice the tables are hand-kept with dated notes, children move between charters, and one
  child is delivered by three tasks of another charter's plan.
- **Proposal:** the table lists children and order; status comes from the plans. Say what a
  child with no plan of its own must record.

### A7. Validate the charter's graph
- **Evidence:** plans get cycle, undefined-dependency and file-overlap checks. A charter's build
  order gets none, and no audit lens reads a charter as a charter.
- **Proposal:** the same structural checks for a charter (no cycle, every dependency names a
  child or a contract, every contract has one owner). Decide whether a charter gets lenses.

### A8. Two documents share the word "charter"
- **Evidence:** the *audit charter* (repo facts the lenses read) and the *superspec charter*
  (decomposition) are unrelated. The `charter` lens reads the first.
- **Proposal:** rename one in the docs, or always qualify both.

## B. Wait for the wave trial

The trial runs the pattern by hand and needs no plugin change. Lift these only from what it shows.

### B1. A checkpoint marker in the plan format
`checkpoint: true` on a task, or a plan-level `waves:` list, so authors stop writing the barrier
edges by hand.

### B2. Validate the barrier
Every task is upstream or downstream of each checkpoint. Today this is checked by hand.

### B3. Named exports per wave
A wave states what it delivers, so a charter edge and a downstream plan's pre-flight can name it.
This is the join between the two kinds of split (see Why).

### B4. An executor step at a checkpoint
Cut the branch, record the commit, carry on, with an option to pause. The executor has no branch
or MR concept today, and merge-back needs a moment with no task running, which continuous
dispatch rarely gives.

### B5. Status commits grouped per tick or per wave
One consuming plan produced 59 status commits out of 143.

### B6. Re-test after a merge-back
A review fix on wave N can change code that finished wave N+1 tasks already built on. Git may
merge it cleanly. Re-run the affected tasks' tests on each merge-back.

## C. Model fit (Fable 5.2, Opus 5.5, Sonnet 5.5, Haiku 5.5)

Added 2026-11-12 from a read of the skills and agents against Anthropic's migration guidance
for these models. The 2026-10-05 effort pins (d5b6e4a) already cover most of the Opus 5.5 and
Sonnet 5.5 changes, and pressure language is rare. What is left is mostly in the executor.

### C1. Two rules contradict each other
- **Evidence:** on an `opus` task that reports BLOCKED, `executing-dag-plans/SKILL.md:73` says
  retry at `opus` and `implementer-prompt.md:130` says go straight to `failed`. The hard rule at
  `SKILL.md:111` ("do not skip either review stage; spec first, then quality") contradicts
  `merged` review mode, which runs both in one pass by design.
- **Proposal:** make one rule for each. Small; do it first.

### C2. Per-dispatch effort and a `fable` tier
- **Evidence:** d5b6e4a says effort is frontmatter-only and that the Agent tool cannot set it per
  dispatch. The Agent tool now takes `effort` when a skill asks for it, and its `model` field
  accepts `fable`. An `opus` task that reports BLOCKED has nowhere to go.
- **Proposal:** on BLOCKED, retry first on the same model at the next effort level, then move up
  a model tier. Add `fable` as an opt-in tier (never a default: Fable 5.2 costs twice Opus 5.5).
  Fall back to today's behaviour on a harness without the `effort` field.

### C3. The executor stops after every tick
- **Evidence:** `executing-dag-plans/SKILL.md:40` ends each tick by waiting for the user to say
  "continue". Subagents now run in the background and wake the controller when they finish. The
  Fable 5.2 guidance names early stops as a behaviour to remove, and this line teaches one.
- **Proposal:** advance on each completion: dispatch newly ready tasks and start reviews as
  results arrive. Stop only when nothing is running and nothing is ready, or on a hard failure.

### C4. Mechanical work done by the controller model
- **Evidence:** each tick the controller sorts the graph, computes the ready set, redraws the
  mermaid block and the ASCII tree, and checks enum values by hand. These have one right answer.
  The v0.6.0 spec states the same principle: resolve facts mechanically.
- **Proposal:** a plan-state script beside `git-commit-safe`. It also gives A7 and B2 their
  checks, and cuts controller tokens most when the session runs on Fable.

### C5. Measure before changing the tier and effort defaults
- **Evidence:** in Anthropic's testing Opus 5.5 at `medium` beats Opus 5 at `high`; the lenses
  and reconciler run at `opus`/`high`. Opus 5.5 is notably better at code review with fewer
  false alarms, at twice Sonnet's price; the quality reviewer runs on `sonnet`. Haiku 5.5 is much
  stronger as a subagent and costs about a twentieth of Sonnet; S9 drops to `cheap` only for
  docs-only tasks.
- **Proposal:** run the audit and review fixtures at the alternative settings and change a
  default only where the fixtures hold.

### C6. Say which model runs the controller
- **Evidence:** the README does not say. Fable 5.2 delegates readily and at high effort reviews
  its own work with subagents, which doubles this plugin's required review chain.
- **Proposal:** recommend Opus 5.5 for the controller session.

## v0.6.0 (merged 2026-11-12)

`docs/superpowers/plans/2026-08-27-seams-and-ground-truth-dag.md` was executed (15/15) on
2026-08-28 in another clone, on branch `feat/seams-and-ground-truth`, and never pushed. It was
merged here rather than run again. Two effects on this backlog:

- **A4:** v0.6.0's `spec:` names the design the plan implements, which for a charter child is
  the child's own spec. It cannot also name the superspec charter, so A4 still needs its own
  fields.
- **A8:** v0.6.0 puts the audit charter into the implementer and reviewer prompts. The
  convention from A8 (bare "charter" means the repo's rules; the superspec charter is always
  named in full) now covers those prompts too.

## Order suggested

1. C1, A5, A6, A8 (small; A8 before v0.6.0 runs). Done.
2. Merge v0.6.0 (done). A4 moves to step 5 with A1 and A3, since all three change the
   superspec charter template.
3. C3 and C2 (executor advances on completion; BLOCKED retries raise effort first). Done for
   C3, and for C2's gap at the top tier: an `opus` task retries at `effort: high`. Two parts of
   C2 were left out. An effort step below the top tier would add a second retry, which C5
   should price first. The `fable` tier waits for a plan that needs it; nothing measured says
   one does.
4. C4 (plan-state script). Done: `skills/writing-dag-plans/plan-state` does check, ready, set
   (with the failure cascade), render and tree, and the three plan skills call it.
5. A1 with A3 and A4, then A2. Done, with A7's structural half as `plan-state charter`.
   Still open: A7's other half (whether a charter gets audit lenses) and C5. C6 done (README).
6. B after the trial, B1 to B3 before B4.
