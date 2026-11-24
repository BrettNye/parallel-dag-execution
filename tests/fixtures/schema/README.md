# Schema fixtures

Fixtures for the two OPTIONAL plan-level frontmatter keys added alongside S16
— `spec:` and `default_implementer:` (`plan-format.md` rules #11 and #12).
Same per-feature directory convention as `tests/fixtures/tiers/` and
`tests/fixtures/review-mode/`. Only `should-refuse/` is populated here,
because both keys hold the plugin's no-silent-fallback rule — a bad value
halts rather than warns, matching what the `*_hint` fields already do.

## Buckets

| Bucket | Contract |
|---|---|
| `should-refuse/` | Validating the plan refuses — on the side(s) named below — naming the field and the offending value. A warning instead of a refusal is the failure; so is silent acceptance. |

## Why `default_implementer` needs two fixtures' worth of care

`spec:` and `default_implementer:` look like siblings — both OPTIONAL, both
refuse rather than warn — but their enforcement is not symmetric, and each
fixture's header has to say so:

| Fixture | Field | Bad value | Enforced by |
|---|---|---|---|
| `bad-spec-unresolvable.md` | `spec` | a path that does not resolve to a readable single file | **both sides** — `writing-dag-plans` step 6 (authoring, rule #11) and `executing-dag-plans` step 4 (executor pre-flight). No split, no subtlety. |
| `bad-default-implementer-typo.md` | `default_implementer` | a non-empty but unregistered subagent name | **executor pre-flight only** (`executing-dag-plans` step 4). The authoring check (rule #12) requires only a non-empty string, and this value satisfies it cleanly. |

`default_implementer`'s authoring check cannot see the agent registry — only
the harness the plan will later run in knows what is actually deployed. So a
plan naming an unregistered-but-nonempty subagent is syntactically valid and
**passes authoring**. It is refused only when `executing-dag-plans` resolves
it against the registry before the first dispatch tick — the same check
`implementer:` gets. A fixture that asserted authoring-side refusal here
would be grading behaviour that does not exist; one quietly rebuilt around an
empty string would mistest the exact case this bucket exists to cover.

## Running

Same as the other plan-quality fixture suites: dispatch `writing-dag-plans`
step 6 (and, for `bad-default-implementer-typo.md`, `executing-dag-plans`
step 4's pre-flight) against the fixture and compare the refusal to the
header's declared field and value. These are prompt-level fixtures — no
assertion harness; see `../audit/README.md` for why a mechanical runner
isn't the goal here either.
