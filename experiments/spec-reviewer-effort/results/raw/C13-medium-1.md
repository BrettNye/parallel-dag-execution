APPROVED

All three files match the spec in the diff of commit 6e78ca3.

- **H11 row:** it is appended after H10 in the hard-rules table, with text identical to the spec. Detection algorithm step 2 reads "H1-H11".
- **Refusal example:** the H11 block is added to the refusal-output example verbatim, with the substring `task-schema violates H11 (bare spec pointer in acceptance criteria)`.
- **Refuse fixture:** `tests/fixtures/contracts/should-refuse/h11-bare-spec-pointer.md` has the header comment as specified. It holds a single well-formed task with an impl block and a failing-test block. The only acceptance bullet is "Match the schema exactly per spec §5.1."
- **Pass fixture:** `tests/fixtures/contracts/should-pass/h11-checksum-criteria.md` has the header comment as specified. Its bullet is "Re-exports all 11 schema files (4 entity + 5 input + 2 query) per spec §5.1.", so it carries a checksum plus provenance.
- **Over-build:** none significant. The pass fixture has one extra acceptance bullet ("Each named export is a Zod schema object with a `.parse()` method"). It inlines a requirement and does not trip H11. The implementer fleshed out the fixture bodies, which the spec left open.

I did not carry out Step 6's re-run of H11 against the existing `should-pass/*` corpus, because the review was limited to the three listed files.
