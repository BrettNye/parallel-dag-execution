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

Each warning is presented as a list with: rule number, affected task ids, specific concern, suggested fix. After the list: prompt "save anyway? (y/N)". Default = N. User must explicitly confirm to override.

## Detection algorithm (run on every save)

1. Run `plan-format.md` structural validation (cycles, undefined deps, required fields, file-disjoint parallel branches). Any failure → refuse, exit.
2. Run hard rules H1-H8. Any failure → refuse, explain which rule and which task, exit.
3. Run soft heuristics S1-S7. Collect warnings.
4. Run **decomposition-principles audit** (see `SKILL.md` step 11.5): re-read the plan against DRY / SRP / SoC / industry-standard hygiene with fresh eyes. This is judgment-based, LLM-driven, and complements the mechanical rules above. Collect warnings.
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

Save anyway? (y/N): _
```
