APPROVED. I read all six fixtures in full and ran the spec's verification loop, which exits 0 with no MISSING, NO EXPECTED HEADER or NO TASKS SECTION output.

- **Header block:** Every fixture starts with an HTML comment containing `FIXTURE:`, `EXPECTED: pass`, `COVERS:` and `ASSUMES:`.
- **Plan format:** Each has YAML frontmatter, a mermaid block, `## Context` and `## Tasks`. Every `## Task:` block has yaml with `id`, `depends_on`, `files` and `status`, plus `## Implementation`, `## Acceptance criteria` and a test file path.
- **clean-explicit-contracts-task:** `task-contracts` is a root with two dependents, `task-ingestion` and `task-processor`. Both import from `src/contracts/claim.ts`.
- **clean-implicit-sequencing:** `task-consumer` has `depends_on: [task-definer]` and there is no separate contracts root.
- **clean-no-shared-contracts:** Three root tasks each use their own types file, with no cross-task imports.
- **clean-pre-existing-contracts:** Both tasks import `Claim` from `src/legacy/types.ts`. The HTML comment documents that file as pre-existing, and no task in the plan defines it.
- **h9-transitive-ok:** The chain is a to b to c. `task-c` has `depends_on: [task-b]` only and imports `Pipeline` from `task-a`'s file.
- **s8-schema-file-exempt:** A single `api/billing.proto` holds the messages and the `BillingService` rpc. The comment documents the `.proto` exemption from Branch B.

Nothing in the diff goes beyond the spec. Only the six listed files were added.
