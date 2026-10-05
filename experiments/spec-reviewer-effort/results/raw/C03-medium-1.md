APPROVED

I checked the diff of commit 251855a for skills/updating-dag-plans/SKILL.md against the spec.

- **Hard rules bullet:** The new "consumes a contract defined by an already-`done` task" bullet is added at the end of `## Hard rules`, with text identical to the spec.
- **Step 6:**
  - "add task" now reads "run hard rules H1-H9 (was H1-H6)" with soft heuristics S1, S5, S8.
  - "modify body" now reads "H1, H2, H4, H5, H9" with S2-S4, S6, S8.
  - "rewire `depends_on:`" now reads "S1, S5, H9".
  - "modify `files:`" and "remove task" are unchanged.
- **Required reading:** It now says "Hard rules H1-H9 and soft heuristics S1-S8", and the stale H1-H6/S1-S6 text is gone.
- **Over-build:** The diff touches only those 3 hunks, so nothing else in the file was modified.
- **Five grep verifications:** All five exit 0 against the file content at commit 251855a.

The working tree at HEAD (c725a09) does not contain these changes, so the greps fail there. The file at HEAD lacks the H9/S8 text, and a later commit appears to have reverted or overwritten it. The commit under review is correct, but the implementer or orchestrator should confirm that HEAD is meant to differ.
