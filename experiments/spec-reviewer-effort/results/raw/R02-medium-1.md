APPROVED

- The S10 row in `skills/writing-dag-plans/plan-quality.md` is appended after S9. Its text is identical to the spec.
- Detection step 3 now reads "S1-S10", with no other change.
- Exactly three fixtures were created under `tests/fixtures/review-mode/should-warn/`, and each has the required EXPECTED comment verbatim.
  - **`s10-docs-only-no-merged.md`:** `files: [docs/usage.md]`, title "update usage docs", body under 200 words, no `review_mode`.
  - **`s10-fixture-only-no-merged.md`:** `files: [tests/fixtures/data/sample.json]`, no `review_mode`.
  - **`s10-mechanical-but-security.md`:** title "rename session field", `files: [src/auth/session.ts]`.
- The three fixtures follow the base skeleton, with an id, `depends_on`, files, an implementation block with a test block, and acceptance criteria. I judged them H1-H9 valid by reading them. I did not run a validator.
- Nothing outside the spec was added. The commit touches only the four listed files.
- Not an implementation issue: the fixture-only file path `tests/fixtures/data/...` does not literally match `**/test/fixtures/**` or `**/tests/data/**`. The spec itself prescribes that path and says it matches, so the implementation follows the spec.
