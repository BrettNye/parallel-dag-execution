APPROVED. I found no under-build and no over-build in commit 6e78ca3, and I did not run the Step 6 corpus re-run myself.

- **H11 row:** The row is appended after H10 in the hard-rules table. Its text matches the spec verbatim.
- **Detection algorithm:** Step 2 is updated from H1-H10 to H1-H11. The spec says this was already done in Task 1, so it is a harmless no-op.
- **Refusal-output example:** The example block matches the spec text exactly, including the `task-schema violates H11 (bare spec pointer in acceptance criteria)` substring.
- **Refuse fixture:** `tests/fixtures/contracts/should-refuse/h11-bare-spec-pointer.md` has the required header comment, with EXPECTED, COVERS, the refusal text and ASSUMES. It holds one well-formed task with an implementation block, a failing-test block, and the sole bullet `Match the schema exactly per spec §5.1.`
- **Pass fixture:** `tests/fixtures/contracts/should-pass/h11-checksum-criteria.md` has the required header comment. Its bullet reads `Re-exports all 11 schema files (4 entity + 5 input + 2 query) per spec §5.1.`
- **Second pass-fixture bullet:** The pass fixture has a second bullet, "Each named export is a Zod schema object with a `.parse()` method." That is mild filler. The spec calls for "same task" and does not forbid extra bullets, so I did not treat it as over-build.
- **Scope:** The commit touches only the three listed files.
