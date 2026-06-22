<!-- EXPECTED: WARN S10 — files all docs-only, no risk signal, review_mode resolves to split. Suggest review_mode: merged. -->

---
title: review-mode-fixture
created: 2026-06-22
---

```mermaid
flowchart TD
    task-1["task-1: update usage docs<br/>files: docs/usage.md"]

    classDef done fill:#90ee90,stroke:#333
    classDef ready fill:#fffacd,stroke:#333
    classDef running fill:#87ceeb,stroke:#333
    classDef failed fill:#ffb6c1,stroke:#333
    classDef skipped fill:#d3d3d3,stroke:#333,stroke-dasharray: 5 5
```

## Context

Fixture for S10 review-mode suggestion. Single docs-only task; structurally valid. All files are under `docs/`, body is under 200 words, no risk signals present, and no `review_mode` is set (resolves to `split`). S10 fires: a clearly-mechanical docs-only edit with no risk signals gains nothing from a two-call split review; suggest `review_mode: merged`. Hard rules H1-H9 all pass.

## Tasks

## Task: update usage docs

```yaml
id: task-1
depends_on: []
files: [docs/usage.md]
status: pending
```

Update the usage documentation to reflect the new `--verbose` flag added in the last release. The flag controls whether progress output is shown during plan execution.

## Implementation

```markdown
<!-- docs/usage.md excerpt -->
## Flags

- `--verbose` — print per-task progress lines during execution. Omit for silent mode.
```

```markdown
<!-- no code test; doc fixture uses a prose diff block as the second fenced block -->
<!-- verify: docs/usage.md contains the --verbose flag entry after this task -->
```

## Acceptance criteria

- `docs/usage.md` documents the `--verbose` flag with a one-line description.
- The description matches the flag's actual behavior (progress output on/off).

Test file: `tests/fixtures/docs/usage-verbose-check.md`.
