# Plan quality reference

Canonical reference for plan-decomposition quality. Both `writing-dag-plans` (authoring) and `updating-dag-plans` (mid-flight mutation) check plans against these rules.

Quality rules are split into two classes:

- **Hard rules** — mechanically detectable, produce failure. Plan refuses to save until resolved.
- **Soft heuristics** — judgment-based, surface as warnings. User can override on confirmation.

## Why this exists

A plan can pass `plan-format.md`'s structural validation (no cycles, file-disjoint parallel branches, required fields) and still be poorly decomposed: compound tasks doing five things at once, duplicated abstractions across sibling tasks, mixed concerns crammed into a single task body. This file catches *decomposition* quality, complementing `plan-format.md`'s *structural* validity.

The two files together define what "a good plan" means in this plugin.

## Principles

### DRY (Don't Repeat Yourself)

Two tasks should not implement the same abstraction. If two parallel tasks both need a `validate-file-scope` helper, hoist it into a shared task that both depend on — OR assign it to whichever task naturally owns it and make the other task `depends_on:` that one.

DRY does NOT mean "no similar-looking code anywhere." Three similar lines is better than a premature abstraction. Apply judgment: would a future maintainer be surprised that these are two separate implementations? If yes → fix. If the similarity is incidental → leave it.

### Single Responsibility (per task)

Each task does one thing. "Implement auth and update README and add tests" is three tasks. Compound tasks are mechanically detectable (see hard rules H1, H2) and refused at save time.

This is the per-task version of SRP. The DAG as a whole can span many responsibilities; individual tasks must not.

### Separation of Concerns

Different concerns belong in different tasks. A task touching both `src/api/` and `src/ui/` is doing API work AND UI work — usually two tasks. The exception: tasks whose explicit purpose IS to wire concerns together (e.g., "wire auth UI to auth API"). For wiring tasks, set `is_wiring_task: true` in the YAML so the H3 check passes; the wiring task should `depends_on:` both the API and UI tasks it wires.

### Industry best practices

The implementer subagent enforces these at code-write time (via auto-loaded `superpowers:test-driven-development` and `superpowers:verification-before-completion`). The planner's job is to ensure each task spec **doesn't forbid them**. Specifically:

- Task body must include verifiable acceptance criteria. A task without measurable success conditions is unimplementable under TDD.
- Task body must not contain anti-pattern phrases that explicitly waive discipline ("skip tests for now", "just patch it", "we'll refactor later").

## Hard rules (refuse on violation)

| # | Rule | Detection |
|---|---|---|
| H1 | **Single Responsibility — no compound titles** | Task title (the `## Task: <title>` line) does not contain `\b(and|also|then|plus)\b` or `&` joining two verb-like phrases. Heuristic check on title text. |
| H2 | **Single Responsibility — single acceptance group** | Task body contains exactly one `## Acceptance criteria` (or `## Test plan`) subsection. Two such subsections in one task body = compound task. |
| H3 | **SoC — single subsystem in `files:`** | All entries in `files:` share a subsystem prefix (first two path segments, e.g., `src/api/`). Mixed prefixes require explicit `is_wiring_task: true` in the task YAML. |
| H4 | **Acceptance criteria present** | Task body MUST include a `## Acceptance criteria` or `## Test plan` heading with at least one bullet. Tasks without verifiable criteria are unimplementable. |
| H5 | **No anti-pattern phrases** | Task body must not match (case-insensitive): `skip\s+tests`, `(don't\|do not)\s+test`, `just\s+patch`, `quick\s+fix\s+for\s+now`, `we'?ll\s+(refactor\|clean.*up)\s+later`. |
| H6 | **Naming consistency** | All `id:` values follow the same convention within a plan: either `task-<N>` (numeric) or `task-<slug>` (kebab) — not mixed. |
| H7 | **`## Implementation` subsection presence** | Tasks without `is_wiring_task: true` MUST have a `## Implementation` subsection (level-2 heading exactly `## Implementation`) containing **at least two** fenced code blocks per `plan-format.md` "Per-task body structure": one minimum-viable impl, one minimum-viable failing test. Detection: locate the `## Implementation` heading; count fenced code blocks before the next level-2 (`## `) heading. Fewer than 2 fails. Tasks with `is_wiring_task: true` are exempt — they may omit the subsection entirely. |
| H8 | **Import resolution** | Every `import`/`require` referenced in any code block in any task body MUST resolve to one of: (a) an external dependency declared in the project's `package.json` / `Cargo.toml` / `pyproject.toml` / equivalent; (b) a file created by some task in this plan (listed in some task's `files:`); (c) a file pre-existing in the target codebase (verified by reading the filesystem). Detection: regex-extract `import .* from ["']<path>["']` and `require\(["']<path>["']\)` from each code block; for each path classify and verify resolution. Refuse on any undeclared import. Output names the offending task, the import statement, and a concrete fix ("create a task that owns this file" or "verify the file pre-exists in the codebase"). External-dep detection MAY require reading `package.json`; relative-path detection MUST resolve against the task's `files:` directory or the codebase root. |
| H9 | **Contract-sequencing — consumer must depend on definer** | Build a definer index by parsing fenced code blocks under `## Implementation` for every task and extracting defined contract symbols per language: TS/JS `export (interface\|type\|class\|function\|const) <Name>` and `export default ...`; Python top-level `class <Name>`, `def <Name>(`, `<Name>: TypeAlias`, `@dataclass class <Name>`, `class <Name>(Protocol)`, `class <Name>(TypedDict)`; Rust `pub (struct\|enum\|trait\|fn\|type) <Name>`; Go top-level `(type\|func) <Name>` with capitalized first letter; JSON Schema top-level `definitions:` / `$defs:` keys; OpenAPI `components.schemas:` keys; protobuf `message`/`enum`/`service <Name>`; GraphQL `type`/`interface`/`enum`/`input <Name>`. Build map `(file_path, symbol_name) → defining_task_id`. Then build a consumer index by scanning each task's code blocks for references to definer-index symbols (imports per H8 extraction + direct usage in code). For each `(consumer_task_id, defined_symbol_name, definer_task_id)` triple where consumer ≠ definer: compute the transitive `depends_on:` closure of consumer (DFS). If `definer_task_id ∉ closure` → violation. Skip pre-existing files (per H8's classification), external package imports, and same-task references. Wiring tasks (`is_wiring_task: true`) apply normally — they should already `depends_on:` their parents by convention. |
| H10 | **Missing-producer — consumed member has no definer** | Extend H9's per-task defined-symbol index to include members/methods/fields within exported classes/objects (not just top-level exports). For each task, collect two kinds of cross-task consumption: (a) member/property/method accesses `base.member` where `base` is a symbol IMPORTED from a file owned by ANOTHER task T (per H8's file-classification) — local variables and parameters are NOT bases and never fire; and (b) named imports `import { member } from <path>` where `<path>` is owned by T and `member` is not a top-level export of T (i.e. it is expected to be a member-level symbol). For each collected `member`: if `member` is absent from T's defined-symbol set (top-level exports ∪ indexed members) → violation. Skip symbols/members resolving to a pre-existing file or external dependency (inherits H9/H8 skips — covers externally/dynamically-produced capabilities), and same-task references. A naming mismatch (consumed `myTasks` vs produced `tasksForUser`) fires by design — the named capability is not wired. **Partition with the prose sweep (step 8):** H10 owns references in code blocks; the prose sweep owns references appearing only in prose/acceptance text. A reference in both yields the H10 finding only. |
| H11 | **Bare spec pointer in acceptance criteria** | An acceptance-criteria bullet whose substantive content is ONLY a spec reference: matches a section-pointer pattern (case-insensitive `§`, `per spec`, `see §`, `match spec section`, `as in section`, `follows §`) AND, with the reference removed, carries no concrete requirement text and no countable checksum (a verifiable number/quantity, e.g. "11 schema files", "13 event names"). A bullet that inlines the requirement and ALSO cites the section as provenance passes — provenance is encouraged. Fix: inline the requirement fragment, or add a countable checksum. (Whether a checksum is a good one is judgment — not gated.) |

On any hard rule failure: refuse to save. Output a specific message naming the task `id`, the rule number, and a concrete suggested fix. Do not write the plan file.

## Soft heuristics (warn and confirm)

| # | Heuristic | Detection |
|---|---|---|
| S1 | **DRY across siblings** | Two parallel tasks (sharing the same set of `depends_on:` parents OR both root) have semantically similar bodies. LLM judgment call: "do these describe the same abstraction in different places?" Surface task ids and ask. |
| S2 | **Task too large** | Task touches >5 files OR body is >800 words. Suggest splitting. |
| S3 | **Task too small / stub** | Task body is <50 words AND `files:` has exactly 1 entry AND no acceptance criteria detail. May be undecomposed. Ask. |
| S4 | **Vague acceptance criteria** | Task has `## Acceptance criteria` but bullets are single-word like "works", "passes", "done". Ask for concrete observable behaviors. |
| S5 | **DAG too linear** | One linear chain of >5 tasks with no parallel branches. The plugin's value is parallelism — flag in case parallelizable work was missed. |
| S6 | **Premature abstraction signal** | Task body mentions creating a new framework/abstraction/helper without a `## Why this abstraction` (or equivalent) justification. Premature abstraction is one of the highest-cost mistakes; surface it. |
| S7 | **Test-helper hoisting** | When two or more non-wiring tasks reference the same project-internal helper file via imports (typically `tests/helpers.*`, `tests/fixtures.*`, `tests/factories.*`, `tests/setup.*`) AND that file is not owned by any task's `files:` AND it is not pre-existing in the codebase, suggest a dedicated root task (e.g., `task-test-helpers`) that owns the helper file. Tasks that share helpers without an owner risk ad-hoc duplication when the implementer subagent for one task is dispatched first. Detection: use the same import-extraction pass as H8; cluster imports by resolved file path; flag any non-owned, non-pre-existing helper file referenced by ≥2 tasks. |
| S8 | **Contract co-location** | At validation start, glob the repo for `**/contracts/**`, `**/types/**`, `**/schemas/**`, `**/models/**`, `**/proto/**`, `**/openapi/**`, `src/types/**`, `src/schemas/**`, `src/contracts/**`. Filter to dirs with ≥3 files (`detected_dirs`). **Branch A — `detected_dirs` non-empty:** for each task with defined contract symbols, warn when symbol's file path doesn't start with one of `detected_dirs`. **Branch B — `detected_dirs` empty:** warn when contract symbols are defined alongside non-contract code in the same file (function bodies with side effects, top-level statements like `console.log` / `fetch` / `db.query` / runtime expressions outside type contexts). Schema-as-code files (`.proto`, `.openapi.yaml`, `.openapi.yml`, `.graphql`) and test files (paths under `tests/` or `test/`) are exempt from Branch B. Wiring tasks (`is_wiring_task: true`) exempt from S8 entirely. Warns at the definer site only — never on consumers. |
| S9 | **Tier-complexity mismatch** | After resolving tiers via `resolve_tier` (per-task hint → plan-level default → `standard`), check each task for mismatches between resolved tier and task complexity signals. Apply these five detection patterns (trigger → suggested action): (1) All entries in `files:` are docs/fixture/test-data paths (matching `docs/**`, `tests/**`, `test/**`, `fixtures/**`, `*.md`, `*.mdx`, `*.txt`) AND task body is <200 words AND `resolve_tier(task, "model")` == `standard` → suggest `model_hint: cheap`. (2) Body text matches novelty-signal regex (case-insensitive: `consensus algorithm`, `distributed`, `formal proof`, `cryptographic`, `zero-knowledge`, `state machine replication`, `byzantine`) AND `resolve_tier(task, "model")` == `standard` → suggest `model_hint: opus` AND `quality_reviewer_hint: opus`. (3) Any entry in `files:` matches a security path glob (`**/auth/**`, `**/authn/**`, `**/authz/**`, `**/crypto/**`, `**/secrets/**`, `**/session/**`, `**/token/**`, `**/jwt/**`) AND `resolve_tier(task, "quality_reviewer")` != `opus` → suggest `quality_reviewer_hint: opus`. (4) Task body contains a `## Why this abstraction` heading AND `resolve_tier(task, "model")` == `standard` → suggest `model_hint: opus`. (5) `is_wiring_task: true` AND `files:` spans >2 distinct subsystem prefixes (first two path segments, e.g., `src/api/`, `src/ui/`) AND `resolve_tier(task, "quality_reviewer")` != `opus` → suggest `quality_reviewer_hint: opus`. S9 suggests **upshifts** on elevated-risk signals; suggests **downshifts only for clearly-mechanical tasks**, never ambiguous ones — this protects the first-pass-parity bar. Note: S9's Pattern 2 novelty regex is deliberately scoped to per-task precise signals and is intentionally different from the plan-level aggregate novelty regex in `writing-dag-plans` SKILL step 6.6 — they are not duplicates and should not be reconciled. |
| S10 | **Review-mode suggestion (merged)** | Suggest `review_mode: merged` for a task when ALL hold: (a) clearly mechanical — uses a signal set parallel to S9's, intentionally distinct (S9 governs tier; S10 governs review mode) — not duplicates, do not reconcile. Concretely: `files:` all match docs/fixture/test-data globs `**/*.md`, `**/test/fixtures/**`, `**/tests/data/**`, `**/CHANGELOG*`, `**/README*`, OR title/body matches `\b(rename\|format\|move\|copy\|extract\|inline\|docs?[-_]only\|test[-_]data\|fixture[-_]only)\b`; (b) trips NONE of S9's risk signals (novelty regex `\b(algorithm\|protocol\|state machine\|consensus\|concurrency\|race\|lock\|transaction\|cryptograph\|atomicity)\b`, `## Why this abstraction` heading, or security-path globs `**/auth/**`, `**/security/**`, `**/crypto/**`, `**/payments/**`, `**/session*`); (c) `resolve_review_mode(task)` resolves to `split`. Suggested action: `review_mode: merged`. Single-direction — only nudges clearly-safe tasks toward merging, never the reverse; a risk signal suppresses the suggestion. |
| S11 | **Unanchored cross-cut contract** | An interface crossing a subsystem cut (two tasks whose `files:` span distinct top-level subsystem prefixes — first two path segments, e.g. `src/api/` vs `src/ui/`, `apps/api/` vs `apps/modules/`) where one side asserts a response/payload shape and no single shared schema both sides `depends_on` defines it. **Suppressor (high-signal):** fire ONLY on a composite, unnamed shape — an object/envelope with ≥2 fields (e.g. `{ items, nextCursor }`). Exempt when the crossing value is a primitive (`number`/`string`/`boolean`) or a shape already named in a shared type both sides reference. Single-direction nudge: suggest adding a shared contract schema as its own task that both sides depend on. |

### S12–S15: can the acceptance criterion FAIL?

S1–S11 police the *shape* of a decomposition. H4 checks that a task **has** acceptance criteria; nothing checks that they can **fail**. These four close that gap, and they exist because of a measurement rather than a preference: on the one plan where audit findings were scored against the commits that actually caused rework, **every rework commit was an AC-falsifiability defect and none was an H-rule finding** — a guard whose scanner silently skipped and left the criterion satisfied, a mutation-verified vacuous assertion that stayed green with the code deleted, and two assertions weaker than their claim.

All four are **soft** by design. Every one of these shapes has a legitimate form, and the suppressors are the load-bearing part: a rule that fires on the correct form teaches authors to ignore it.

| # | Heuristic | Detection |
|---|---|---|
| S12 | **Crash-passing absence criterion** | A criterion asserts a *negative* outcome — matching (case-insensitive) any of: `\bno\b.{0,40}\b(is\|are)\b.{0,20}\b(written\|issued\|called\|created\|sent\|persisted\|emitted\|enqueued\|appended)\b` (passive), `\b(issues\|writes\|creates\|sends\|emits\|persists\|appends\|finds\|returns)\b\s+(no\|none\|nothing)\b` (**active** — authors use this voice at least as often, and the first draft of this rule listed only the passive form, so it silently under-fired on "Cancel issues no DELETE"), `does ?n[o']t\b.{0,20}\b(call\|write\|issue\|emit\|send\|append)\b`, `\b(is\|has\|remains\|stays\|is left)\b.{0,20}\b(undefined\|null\|empty)\b` (a bare state-nullness claim like "the row **has** `voided_at` null" passes on an empty table just as readily as on a crash — the one-word gap from `is` to `has` was letting it through), `toBeUndefined`, `toBeNull`, `toBeFalsy`, `toBe(false)`, `not\.toBe(true)`, `not\.toHaveBeenCalled`, `\.length === 0` — AND **nothing in this task's acceptance criteria asserts a positive outcome through the same observation channel** (same collaborator, spy, table, or endpoint noun). Such a criterion passes when the code under test throws *before* reaching the observation point: nothing was called because nothing ran. **Match scope:** the bullet text *plus the assertion it names*, whether written inline or shown for it in `## Implementation`. The last four patterns are test-API tokens that live in code rather than prose, so a bullet-text-only scope would list triggers it could never see — and S14 already reads "its stated assertion" this way, so the two rules must agree. **Suppressor:** a positive exercise of the same channel anywhere in this task's criteria, **including inside the very same bullet** ("Cancel issues no DELETE, asserted with the same spy that sees exactly one DELETE on confirm"). Demanding a separate *sibling* bullet would fire on that correct one-bullet form. Fire once per task, not per bullet. Suggested fix: add the positive companion to the *same* task, since a reviewer sees only this task's body. |
| S13 | **Tautological criterion** | LLM judgment call, like S1 — not a regex. For each criterion asserting a specific expected value, ask: *is that value sourced from the declaration this task is creating?* Extract `const` / `export const` / enum / literal declarations from the task's `## Implementation` block (reuse H9's definer index, scoped to this task — a constant the block *imports* from a file this task does not declare is **not** in the index, since the task is not creating it) and flag a criterion whose expected value exists only there — the test will import the constant and assert it equals itself, staying green for any value including a wrong one. **Suppressors:** the criterion's **assertion compares against a literal written in the criterion** rather than against the declaration — this holds *even when the same digits also appear in the impl block*, because restating the value as an AC literal is the **cure** for tautology, not a symptom: change the declaration and the test fails, which is the entire question S13 asks. (An earlier draft added "*and* that literal does not appear in the impl block", which contradicted the trigger clause outright — the trigger asks whether the value exists *only* in the declaration, so the two sentences returned opposite verdicts on the same criterion depending on which was read second. It also penalised the cure on nearly every correct task, since H7 *requires* the impl block to show the real value. Found by a blind fixture run.) Or the assertion is about a declaration's *shape* rather than its value, where the declaration genuinely is the requirement (`the column is nullable timestamptz`). Suggested fix: state the expected value in the criterion, or assert against a known-good vector. |
| S14 | **Quantifier mismatch** | The criterion's text makes a *universal* claim — `every`, `all`, `each`, `none of`, `no other`, `exhaustive` — while its stated assertion is *existential*: `toContain`, `toBeDefined`, `includes`, `at least`, `length > 0`, `toBeGreaterThan(0)`. Also fires when the text names a set size (`each of the seven reasons`) but the criterion describes fewer cases than that size. Proving "at least one" does not prove "every", and the members left unenumerated are where it broke. **Suppressor:** the criterion draws its iteration set from an exported enum/array rather than a hand-written list — so a newly added member fails the test — or asserts count-equality against that set's length. **The suppressor must discharge the same predicate the claim makes.** Count-equality proves *coverage* and nothing else, so it discharges "every status is mapped" but **not** "every status maps to a **non-empty** label" — a record whose every value is `''` satisfies the count and violates the sentence. When the universal claim carries a per-member property, the suppressor applies only if the iteration asserts *that property* per member. (This gap was found by running the rule against its own must-not-warn fixture, where the suppressor silenced a genuinely defective criterion.) Suggested fix: iterate the exported set, or assert an exact count — and assert the claimed property inside the loop. |
| S15 | **Diff-property criterion** | The criterion asserts a property of the *commit* rather than of *behaviour*: `untouched`, `unchanged`, `not modified`, `byte-identical`, `no other .{0,30}(change\|edit\|file)`. **Subject restriction — check this before firing:** the subject of the claim must resolve to a **file or path**. "`legacy-dialog.component.ts` is untouched" fires; "the row is unchanged", "the other fields are unchanged", "the balance is unchanged" do **not** — a runtime entity's state is ordinary observable behaviour and reading it back is exactly the right test. Without this restriction the token list is a false-positive generator on some of the most common legitimate phrasing in any plan, and three independent runs against these rules all flagged it. A test cannot observe whether a file was edited, so the criterion is unexecutable and gets marked verified on the implementer's word. **Escalate the warning when the file named as untouched also appears in that task's own `files:` list** — then no scope check can enforce it either, because an implementer who edits it is *inside* their declared scope, and the criterion is unenforceable from both directions at once. **Suppressor:** already stated positive-with-control (the thing IS found where it should be, and absent where it should not be). Suggested fix: restate as positive-with-control, and remove the file from `files:` so the no-edit boundary is owned by review rather than asserted by a unit test. |

**All four fire once per task, not once per bullet** — S12 said so and S13–S15 did not, leaving the warning count undefined for a task with three offending criteria. Report the task once and name every criterion that contributed.

Each warning is presented as a list with: rule number, affected task ids, specific concern, suggested fix. After the list: prompt "save anyway? (y/N)". Default = N. User must explicitly confirm to override.

## Detection algorithm (run on every save)

1. Run `plan-format.md` structural validation (cycles, undefined deps, required fields, file-disjoint parallel branches). Any failure → refuse, exit.
2. Run hard rules H1-H11. Any failure → refuse, explain which rule and which task, exit. Note: H10 requires a member-level index extension over H9 — extend the definer index built in H9 to include methods/fields/properties within exported classes/objects before running H10's member-access scan.
3. Run soft heuristics S1-S15. Collect warnings. S12-S15 read each task's `## Acceptance criteria` bullets and, for S12/S15, cross-check them against that task's own sibling bullets and `files:` list.
4. Run **decomposition-principles audit** (see `SKILL.md` step 8): re-read the plan against DRY / SRP / SoC / repo-convention adherence with fresh eyes. This is judgment-based, LLM-driven, and complements the mechanical rules above. Collect warnings.
5. If warnings exist (from step 3 or step 4): present grouped list, ask "save anyway? (y/N)" (default N).
6. On user confirm OR no warnings: save plan file.

## Examples

### Bad: compound task (refused, H1)

```yaml
id: task-3
files: [src/auth.ts, README.md, tests/auth.test.ts]
depends_on: []
```

```markdown
## Task: implement auth and update README and add tests

Build the OAuth2 flow, document it in README, write integration tests.
```

**Refused** — H1: title joins three verbs with `and`. H3: `files:` spans `src/`, `README`, and `tests/` (three subsystems). Suggested split:

- `task-3a: implement OAuth2 flow` → `files: [src/auth.ts]`
- `task-3b: integration tests for auth` → `files: [tests/auth.test.ts]`, `depends_on: [task-3a]`
- `task-3c: document auth in README` → `files: [README.md]`, `depends_on: [task-3a]`

### Bad: SoC violation (refused, H3)

```yaml
id: task-7
files: [src/api/users.ts, src/ui/UserList.tsx]
depends_on: []
```

**Refused** — H3: `files:` spans `src/api/` and `src/ui/`. Either split into two tasks (one per subsystem), or if this task's explicit purpose IS to wire them, set `is_wiring_task: true` AND add `depends_on:` for the API and UI tasks it wires.

### Bad: missing Implementation subsection (refused, H7)

```yaml
id: task-foo
files: [src/foo.ts]
depends_on: []
status: pending
```

```markdown
## Task: implement foo

This task implements the foo helper. The implementer should write the function and tests.

## Acceptance criteria

- foo(2) returns 4.
- foo(0) returns 0.
```

**Refused** — H7: no `## Implementation` subsection. The task lists a `.ts` file in `files:` but the body has zero fenced code blocks anchoring the implementation. Suggested fix: add a `## Implementation` subsection with one impl block and one failing-test block (or set `is_wiring_task: true` if this is pure registration).

### Good: clean decomposition (passes all rules)

```yaml
id: task-2
depends_on: []
files: [src/api/users.ts]
status: pending
```

````markdown
## Task: users API list endpoint

Implement `GET /api/users` returning paginated user list.

## Implementation

```typescript
// src/api/users.ts
export async function listUsers(req: Request): Promise<Response> {
  if (!verifyAuth(req)) return new Response("unauthorized", { status: 401 });
  const limit = Math.min(100, Number(req.query.limit ?? 20));
  const { users, next_cursor } = await db.users.page(limit, req.query.cursor);
  return Response.json({ users, next_cursor });
}
```

```typescript
// tests/api/users.test.ts
it("returns 401 when authorization header is missing", async () => {
  const res = await listUsers(makeReq({ headers: {} }));
  expect(res.status).toBe(401);
});
```

## Acceptance criteria

- Returns 200 with `{ users: User[], next_cursor: string | null }` shape.
- Handles `?limit=N` query param (default 20, max 100).
- Returns 401 if `Authorization` header is missing or invalid.
- Integration-tested against a real test DB (no mocks per project convention).

Test file: `tests/api/users.test.ts`.
````

Passes all hard rules: single concern (one subsystem `src/api/`), one acceptance-criteria group, observable test criteria, no anti-pattern phrases, consistent `task-<N>` naming, `## Implementation` subsection with impl + failing-test blocks.

## Refusal output format

When refusing, the skill prints:

```
✗ Plan refused — quality issues:

  task-3 violates H1 (compound title)
    Title: "implement auth and update README and add tests"
    Issue: title joins three distinct verb phrases with `and`
    Fix:   split into one task per phrase; chain them with depends_on if order matters

  task-3 violates H3 (mixed subsystems in files:)
    Files: src/auth.ts, README.md, tests/auth.test.ts
    Issue: spans src/, README, and tests/ — three subsystems
    Fix:   one task per subsystem (see H1 split suggestion above)

  task-foo violates H7 (missing ## Implementation subsection)
    Files: src/foo.ts
    Issue: no ## Implementation subsection found, or fewer than 2 fenced code blocks within it
    Fix:   add ## Implementation with one impl code block and one failing-test code block
           (or set is_wiring_task: true if this is pure registration)

  task-claims-processor violates H9 (missing contract dependency)
    Symbol: ClaimRecord
    Defined by: task-claims-contracts (file: src/contracts/claim.ts)
    Issue: task-claims-processor references ClaimRecord but does not depends_on task-claims-contracts (transitively)
    Fix:   add "task-claims-contracts" to task-claims-processor.depends_on

  task-component violates H10 (consumed capability has no producer)
    Capability: state.myTasks
    Owner:      task-state (produces state, file: src/state/app-state.ts)
    Issue:      task-component references state.myTasks but task-state defines no myTasks
    Fix:        add a producer for myTasks (state method + its api-client/controller/
                repository data path) OR correct the reference if myTasks was renamed

  task-schema violates H11 (bare spec pointer in acceptance criteria)
    Bullet: "Match the schema exactly per spec §5.1."
    Issue:  criterion defers to a spec section the reviewer never sees; no inlined
            requirement and no countable checksum
    Fix:    inline the requirement fragment, or add a countable checksum
            (e.g. "re-exports all 11 schema files"); citing §X as provenance is fine
            once the requirement itself is present

Plan not saved. Revise and try again.
```

## Warning output format

When soft heuristics fire (no hard failures):

```
⚠ Plan has 2 quality warnings:

  S2 — task-4 is large
    Files: 7 entries; body: 1,200 words
    Concern: large tasks are harder to review and re-dispatch on failure
    Suggestion: consider splitting into smaller tasks

  S5 — DAG is linear (6 tasks in a chain)
    Concern: this plugin's value is parallelism; a linear chain doesn't benefit
    Suggestion: any work in those 6 tasks that could parallelize?

  S8 — task-claims-processor contract co-location
    Symbol: ClaimRecord
    File:   src/claims/processor.ts
    Concern: project uses src/contracts/ for shared types, but ClaimRecord is defined here
    Suggestion: move ClaimRecord to src/contracts/claim.ts

  S11 — task-ui / task-api unanchored cross-cut contract
    Shape:   { items, nextCursor } crossing src/api ⇄ src/ui
    Concern: consumer asserts this envelope; no shared schema defines it; producer
             free to return an incompatible shape (compiles on both sides)
    Suggestion: add a shared contract schema as its own task; make both sides depends_on it

Save anyway? (y/N): _
```
