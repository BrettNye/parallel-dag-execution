# DAG plan format reference

This is the canonical format for DAG-aware execution plans. Both `writing-dag-plans` (authoring) and `updating-dag-plans` (mid-flight mutation) validate plans against this contract.

## File location

Plans live at `docs/superpowers/plans/YYYY-MM-DD-<topic>-dag.md` by default. Override per project preference.

## Top-of-file structure

Every plan file has this structure (in order):

1. YAML frontmatter (title, created date).
2. A mermaid `flowchart TD` block — the DAG visualization, regenerated from scratch on every save.
3. A `## Context` section — why this plan exists, what spec drives it, scope notes.
4. A `## Tasks` heading.
5. One or more `## Task: <title>` sections, each with a YAML block followed by prose.

Example skeleton:

````markdown
---
title: my-feature
created: 2026-05-02
spec: docs/superpowers/specs/2026-05-02-my-feature-design.md  # OPTIONAL. Single file path to the design this plan implements. A superspec charter when the design spans files. Never a directory — a directory cannot be diffed against a claim. An unresolvable `spec:` refuses (does not warn).
default_implementer: dag-implementer    # OPTIONAL. subagent_type fallback for tasks lacking `implementer:`. Resolution order: task.implementer, then default_implementer, then dag-implementer.
parent: docs/superpowers/specs/2026-05-01-platform-charter.md  # OPTIONAL. The superspec charter this plan is a child of. Set together with `child:`.
child: api                              # OPTIONAL. This plan's id in the parent charter's `children:` list.
implementation: full                    # OPTIONAL. Only `full` is valid; the key is kept so older plans that set it still pass. contracts-only was removed after the D1 pilot (rule 14).
default_model_hint: standard            # OPTIONAL. cheap | standard | opus. Default `standard`. Implementer tier.
default_spec_reviewer_hint: standard    # OPTIONAL. cheap | standard | opus. Default `standard`.
default_quality_reviewer_hint: standard # OPTIONAL. cheap | standard | opus. Default `standard`.
test_command: bash {file}       # OPTIONAL. Default: bash {file}. Every {file} becomes the test file, single-quoted; runs as sh -c from the repository root.
test_pass_prefix: "PASS: "      # OPTIONAL. Default "PASS: ". Quote it to keep the trailing space.
test_fail_prefix: "FAIL: "      # OPTIONAL. Default "FAIL: ". A fail line may go on with " (" and detail.
---

```mermaid
flowchart TD
    task-1["task-1: install hook"]
    task-2["task-2: docs"]
    task-1 --> task-2

    classDef done fill:#90ee90,stroke:#333
    classDef ready fill:#fffacd,stroke:#333
    classDef running fill:#87ceeb,stroke:#333
    classDef failed fill:#ffb6c1,stroke:#333
    classDef skipped fill:#d3d3d3,stroke:#333,stroke-dasharray: 5 5
```

## Context

[why this plan exists, what spec drives it]

## Tasks

## Task: install hook

```yaml
id: task-1
depends_on: []
files:
  - bin/install-hook.sh
  - .claude/settings.json
status: pending
```

[prose: implementation details, acceptance criteria, test plan]

## Task: docs

```yaml
id: task-2
depends_on: [task-1]
files:
  - docs/install.md
status: pending
```

[prose]
````

The mermaid block is REQUIRED at the top. It is regenerated from scratch on every save by `writing-dag-plans` or `updating-dag-plans` — never hand-edit it. The block reflects the current DAG including status-driven node coloring.

All three `default_model_hint` / `default_spec_reviewer_hint` / `default_quality_reviewer_hint` frontmatter keys are optional; omitting any (or all) keeps `standard` everywhere = today's behavior.

`default_review_mode: split` (OPTIONAL, `merged | split`, default `split`) sets the review mode for tasks lacking a per-task `review_mode`. Omitting it keeps `split` (today's two-call spec→quality chain).

`spec:` (OPTIONAL) names a single file path to the design this plan implements — a superspec charter when the design spans files. It must be a single file, never a directory: a directory cannot be diffed against a claim. An unresolvable `spec:` (path does not exist) refuses rather than warns.

`default_implementer:` (OPTIONAL, default `dag-implementer`) is the subagent_type fallback for tasks lacking a per-task `implementer:`. Resolution order: `task.implementer`, then `default_implementer`, then `dag-implementer` — matching the `default_*_hint` pattern documented above.

`parent:` and `child:` (OPTIONAL, set together) place a plan inside a superspec charter: `parent:` is the charter's path and `child:` is this plan's id in the charter's `children:` frontmatter list. They are separate from `spec:`, which names the design this plan implements; for a charter child that is the child's own spec. A status board or a reader goes from charter to plans through `children:` and the Children table's `plan` column, and from a plan back to its charter through `parent:`.

## Per-task frontmatter schema

Every `## Task: ...` heading is immediately followed by a YAML block:

```yaml
id: task-N             # REQUIRED. Stable identifier. Used in depends_on edges.
depends_on: []         # REQUIRED. List of task ids this task depends on. [] = root.
files:                 # REQUIRED. Files this task creates or modifies.
  - path/to/file.ts
status: pending        # REQUIRED. pending | ready | running | done | failed | skipped
implementer: dag-implementer  # OPTIONAL. subagent_type to dispatch for this task. Falls back to `default_implementer`, then `dag-implementer`. Use to route specialized tasks to persona-typed subagents (e.g., profile-charmeleon for backend, profile-gastly for tests). The named subagent must be available in the harness's agent registry at dispatch time.
model_hint: cheap             # OPTIONAL. cheap | standard | opus. Implementer model selection hint. Falls back to `default_model_hint`, then `standard`.
spec_reviewer_hint: standard    # OPTIONAL. Spec reviewer tier. cheap | standard | opus. Falls back to default_spec_reviewer_hint, then `standard`.
quality_reviewer_hint: standard # OPTIONAL. Quality reviewer tier. cheap | standard | opus. Falls back to default_quality_reviewer_hint, then `standard`.
review_mode: merged    # OPTIONAL. merged | split. Falls back to default_review_mode, then `split`. `merged` runs one combined spec+quality reviewer instead of the two-call chain.
single_threaded: false # OPTIONAL. If true, task forces dispatch tick to itself. Use for scope-less/exploratory tasks.
is_wiring_task: false  # OPTIONAL. If true, plan-quality.md H3 (single-subsystem in files:) is bypassed. Use only for tasks whose explicit purpose is to wire two subsystems together; should depend_on the tasks producing each side.
review_rounds: 0       # OPTIONAL. Whole number 0-3. Fix rounds so far: re-dispatches of the implementer after a reviewer's ISSUES verdict. Absent = 0. Written by `plan-state round`; nothing lowers it.
tests:                 # OPTIONAL. Block list only. Each entry "<file> :: <case>": the test cases that prove this task. <file> must be in files:. Checked by verify-tests.
  - tests/plan-state/plan-state.test.sh :: round on "2" counts to 3
base_sha: 1f3c9e0      # Written by plan-state set ... running, the first time only. Never hand-edited.
```

### Mixing implementers in a single plan

When a plan has tasks for different specialized subagents, set `implementer:` per task. Example: a plan with backend tasks for `profile-charmeleon` and test-infrastructure tasks for `profile-gastly` declares each accordingly. The executor reads `implementer:` per dispatch and selects the subagent_type at runtime. Tasks without an `implementer:` field fall back to `default_implementer` (when set), then `dag-implementer`.

The spec and quality reviewers (`dag-spec-reviewer`, `dag-quality-reviewer`) are persona-agnostic — they review the diff against the task spec and code quality regardless of which implementer wrote it. There's no per-task review override.

### Named tests

`tests:` names the test cases that prove a task, so the executor can check them instead of trusting a summary. It is a block list; each entry reads `<file> :: <case>`.

- **Entry grammar.** The raw entry is taken literally. It is split at the first ` :: `. `<file>` is trimmed and a leading `./` is removed; `<case>` is trimmed. Two entries are the same when their normalised `(file, case)` pairs are equal. `<file>` must be listed in the task's `files:`.
- **Unique case names.** A case name must be unique in its file: the test file prints one line per case, and the matcher finds a case by that line, so two cases with one name cannot be told apart.
- **Matching rule.** The test file runs through `test_command` from the repository root. A case `passed` when a line equals `test_pass_prefix` followed by the case name. It `failed` when a line equals `test_fail_prefix` followed by the case name, optionally followed by ` (` and detail. It is `absent` when no line names it. It is `ambiguous` when its lines disagree, for example a pass line and a fail line, or the same line more than once.
- **`base_sha`.** `plan-state set <plan> <id> running` writes `base_sha`, the commit the task started from, the first time only. A resume of the same task keeps the value it already has, so the red check always compares against the original start. Nobody edits it by hand.
- **Labels.** `verify-tests` reports one label per entry:
  - `ok` — the case fails (red) at `base_sha` and passes now.
  - `ok-absent` — the case did not exist at `base_sha` (absent) and passes now.
  - `not-red` — the case already passed at `base_sha`, so it proves nothing new.
  - `not-green` — the case does not pass now (failed or absent).
  - `ambiguous` — the case could not be matched to one result.

## Tier resolution

The executor resolves the model tier for each role using the following logic:

```
resolve_tier(task, role) =
    task[role + "_hint"]                               if present
    else plan_frontmatter["default_" + role + "_hint"] if present
    else "standard"

resolve_model(tier) =
    "haiku"  if tier == "cheap"
    "sonnet" if tier == "standard"
    "opus"   if tier == "opus"
```

The three role values are:

- `model` — the implementer. Per-task field: `model_hint`. Plan-level default: `default_model_hint`. The resolver evaluates `task["model" + "_hint"]` = `task["model_hint"]` — the asymmetry is that the role name is `model` while the reviewer roles are `spec_reviewer` / `quality_reviewer`, but all three per-task fields end in `_hint` (`model_hint`, `spec_reviewer_hint`, `quality_reviewer_hint`). This is explicit and intentional.
- `spec_reviewer` — the spec reviewer. Per-task field: `spec_reviewer_hint`. Plan-level default: `default_spec_reviewer_hint`.
- `quality_reviewer` — the quality reviewer. Per-task field: `quality_reviewer_hint`. Plan-level default: `default_quality_reviewer_hint`.

A per-task hint inconsistent with the plan-level default is NOT an error — per-task overrides bypass plan-level defaults entirely.

## Review-mode resolution

The executor resolves each task's review mode:

```
resolve_review_mode(task) =
    task["review_mode"]                        if present
    else plan_frontmatter["default_review_mode"] if present
    else "split"
```

- `split` (default) → the two-call chain: `dag-spec-reviewer` then `dag-quality-reviewer`.
- `merged` → ONE `dag-merged-reviewer` call doing both spec compliance and code quality, returning both verdicts.

A **merged** review resolves its model via the `quality_reviewer` tier — `resolve_model(resolve_tier(task, "quality_reviewer"))` — because it does both jobs and quality is the more demanding one. When a task is `merged`, `spec_reviewer_hint` is unused (not an error). A per-task `review_mode` inconsistent with `default_review_mode` is not an error — the per-task value wins.

## Per-task body structure

Every task body (the prose + code below the YAML block) follows this canonical structure unless `is_wiring_task: true` exempts the task:

1. **One short prose paragraph** (1-3 sentences) describing what this task accomplishes. Cite the driving spec section if relevant.

2. **`## Implementation` subsection.** At least two fenced code blocks for typical code tasks:
   - **Block 1 — minimum-viable impl:** the file being created or modified, showing the load-bearing shape (function signatures, types, key dispatch logic, schema definition). Need not be complete — the implementer subagent fills in helpers, error handling, and edge cases via TDD discipline. But the shape MUST be specific enough that two competent implementers would produce code with compatible interfaces.
   - **Block 2 — minimum-viable failing test:** at least one failing test case anchoring the acceptance criteria. The test should target a single observable behavior from the acceptance bullets. The implementer subagent expands this into a full test suite.
   - Additional blocks are allowed (e.g., CLI command examples, expected output snippets).

3. **`## Acceptance criteria` subsection.** Bulleted observable behaviors. Each bullet should be a concrete check that a reviewer (human or subagent) can verify with a specific test or runtime assertion. No vague bullets ("works", "passes"); see `plan-quality.md` S4.

4. **Test file path.** A single line naming the test file (e.g., `Test file: vault-mcp/tests/unit/foo.test.ts.`). Required so the implementer knows where the failing test from Block 2 lands.

### Wiring tasks (exempt from the `## Implementation` requirement)

Tasks with `is_wiring_task: true` skip the `## Implementation` subsection. Their purpose is registration / cross-subsystem assembly — the load-bearing artifact is the file structure itself, not a novel implementation. Wiring tasks still require:

- One short prose paragraph explaining what's being wired.
- `## Acceptance criteria` with observable behaviors (typically: "X is exposed via Y after this task lands").
- Test file path.

Wiring tasks MAY include a code block showing the import/registration shape but it is optional.

### Example task body (canonical structure)

````markdown
## Task: stable scope hash

```yaml
id: task-scope-hash-helper
depends_on: []
files: [vault-mcp/src/core/scope-hash.ts]
status: pending
```

Pure function. Stable across array order, sensitive to set membership, deterministic, dimension-collision-resistant. Drives identity-tuple computation per spec §5.3.

## Implementation

```typescript
import { createHash } from "node:crypto";

export function scopeHash(profile: string[], move: string[], scope_wiki: string[], tags: string[]): string {
  const dim = (label: string, values: string[]) => `${label}:${[...values].sort().join(",")}`;
  const canonical = [dim("p", profile), dim("m", move), dim("w", scope_wiki), dim("t", tags)].join("|");
  return createHash("sha256").update(canonical).digest("hex").slice(0, 16);
}
```

```typescript
import { scopeHash } from "../../src/core/scope-hash.js";

it("is stable across array order", () => {
  expect(scopeHash(["a","b"], [], [], [])).toBe(scopeHash(["b","a"], [], [], []));
});
```

## Acceptance criteria

- Stable across array order: `scopeHash(["a","b"], [], [], []) === scopeHash(["b","a"], [], [], [])`.
- Membership-sensitive: `scopeHash(["a","b"], [], [], []) !== scopeHash(["a"], [], [], [])`.

Test file: `vault-mcp/tests/unit/scope-hash.test.ts`.
````

## Status semantics

| Status | Meaning | Mutable by `updating-dag-plans`? |
|---|---|---|
| `pending` | Not yet ready (deps unresolved). | Yes |
| `ready` | All deps `done`. Awaiting next dispatch tick. | Yes |
| `running` | Implementer subagent is currently executing. | No |
| `done` | Implementer finished AND spec/quality reviewers approved. | No |
| `failed` | After auto-retry-once, still BLOCKED; or a reviewer's fourth ISSUES verdict, after 3 fix rounds (rule 15); or a reviewer gave no single verdict twice. | No |
| `skipped` | Cascaded from a `failed` ancestor. Will not run. | No |

## Validation rules (enforced by writing-dag-plans + updating-dag-plans)

1. **Unique `id`** — no two tasks share an id.
2. **No cycles** — `depends_on:` graph must be a DAG.
3. **No undefined deps** — every entry in `depends_on:` must reference an existing task id.
4. **File-disjoint parallel branches** — if two tasks share an entry in `files:`, there MUST be a directed path between them in `depends_on:` (one transitively depends on the other). Otherwise reject with a clear conflict report naming both tasks and the overlapping file(s).
5. **Required fields** — `id`, `depends_on`, `files`, `status` per task. Empty `files:` is rejected unless `single_threaded: true`.
6. **Immutable history** — `updating-dag-plans` rejects mutations to any task whose status is `running`, `done`, `failed`, or `skipped`.
7. **Per-task hint enum** — `model_hint`, `spec_reviewer_hint`, `quality_reviewer_hint`, when present on any task, MUST be one of `cheap | standard | opus`. Any other value → refuse save with the offending task id, field name, and the bad value.
8. **Plan-level default enum** — `default_model_hint`, `default_spec_reviewer_hint`, `default_quality_reviewer_hint`, when present in frontmatter, MUST be one of `cheap | standard | opus`. Any other value → refuse with the field name and the bad value.
9. **Per-task review-mode enum** — `review_mode`, when present on any task, MUST be `merged | split`. Any other value → refuse naming the task id, field, and bad value.
10. **Plan-level review-mode enum** — `default_review_mode`, when present in frontmatter, MUST be `merged | split`. Any other value → refuse naming the field and bad value.
11. **`spec:` file validity** — `spec:`, when present, MUST resolve to a readable single file, not a directory. Any other case → refuse, naming the field and the offending path.
12. **`default_implementer` type check** — `default_implementer`, when present in frontmatter, MUST be a non-empty string. Any other value → refuse with the field name and the bad value.
13. **`parent:` / `child:` placement** — when either is present, both MUST be present; `parent:` MUST resolve to a readable single file, and `child:` MUST appear in that file's `children:` frontmatter list. Any other case → refuse, naming the field and the offending value.
14. **`implementation:` mode** — `implementation:`, when present in frontmatter, MUST be `full`. `contracts-only` was removed after the D1 pilot and is refused with `plan-state: rule 14: implementation is contracts-only (removed after the D1 pilot; use full)`. Any other value → `plan-state: rule 14: implementation is <value>`.
15. **`review_rounds` count** — `review_rounds`, when present on any task, MUST be a whole number from 0 to 3. It counts fix rounds; absent means 0. `plan-state round <plan> <id>` raises it by one on a `running` task and refuses at 3 (exit 1), which is the review cap: the executor then marks the task `failed`. Any other value → refuse naming the task id, the field, and the bad value.
16. **Named tests** — `tests:`, when present on a task, MUST be a block list of entries `<file> :: <case>`, each `<file>` MUST be in that task's `files:`, and no entry may repeat (after normalising). `test_command`, when present in frontmatter, MUST contain `{file}`. `test_pass_prefix` and `test_fail_prefix`, when present, MUST NOT be empty. Refusal lines:
    - `rule 16: <id> tests entry "<entry>" is not "<file> :: <case>"`
    - `rule 16: <id> test file <file> is not in its files:`
    - `rule 16: <id> tests entry "<entry>" is repeated`
    - `rule 16: <id> tests must be a block list`
    - `rule 16: test_command has no {file}`
    - `rule 16: test_pass_prefix is empty` (or `test_fail_prefix`)
17. **`base_sha` shape** — `base_sha`, when present on any task, MUST be 7 to 40 lowercase hex characters. Any other value → `rule 17: <id> base_sha is <value>`.

Rules #7–#17 use the same refusal-message format as rules 1–6.

`plan-state check <plan>` (the script beside this file) enforces rules 1–5 and 7–17 and prints one line per violation; rule 6 needs the previous version of the plan and stays with `updating-dag-plans`. `plan-state round` counts a task's fix rounds against the cap of 3 (rule 15). `plan-state render` draws the mermaid block below and `plan-state tree` prints the ASCII tree, so both follow this spec exactly.

## Why `files:` is the load-bearing field

The executor uses `files:` to verify at runtime that no two parallel implementers will clobber each other. Authoring-time validation (writing-dag-plans) ensures parallel branches are file-disjoint **by construction**. Runtime validation (executing-dag-plans) is a tripwire — if it fires, the planner has a bug, not a race condition.

The contract is: declare your scope, and the system guarantees no parallel implementer touches your files. This is what makes continuous parallel dispatch safe.

## Mermaid block specification

The mermaid block uses `flowchart TD` (top-down) layout. Every task is a node:

```
task-id["task-id: short title<br/>files: <first-file>"]
```

If `files:` has more than 2 entries, summarize as `files: <first-file> +N more`.

Edges are drawn from `depends_on:` — each `depends_on: [parent-id]` becomes `parent-id --> task-id`.

Status drives node coloring via `classDef` and `:::class` syntax:

```
task-N["..."]:::done
task-M["..."]:::failed
```

The five `classDef`s at the bottom of the block:

```
classDef done fill:#90ee90,stroke:#333
classDef running fill:#87ceeb,stroke:#333
classDef ready fill:#fffacd,stroke:#333
classDef failed fill:#ffb6c1,stroke:#333
classDef skipped fill:#d3d3d3,stroke:#333,stroke-dasharray: 5 5
```

`pending` tasks get the default mermaid styling (no class).

## ASCII tree rendering (terminal output)

After every save, both writing/updating skills print an ASCII tree to the terminal. The format:

```
DAG: <N> tasks · <D> done · <R> running · <F> failed · <S> skipped · <P> pending

[task-id] short title              <icon> <status>
   │
   └──→ [child-id] short title     <icon> <status>
```

Status icons:
- ✓ done
- ⟳ running
- · pending / ready
- ✗ failed
- ⊘ skipped

For DAGs more than 3 levels deep or wider than 8 leaves at any level, fall back to a flat status table sorted by id.
