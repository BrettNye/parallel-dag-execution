ISSUES

Everything else matches the spec: the H10 row text, the refusal example, the `step 11.5` → `step 8` fix, both fixtures, and the H10 note in step 2. There is one deviation.

Requirement: Step 4 says to change §Detection algorithm step 2 to run "hard rules H1-H11" and to add a note that H10 needs the member-level index extension over H9.
Actual: In commit f7b2bae, step 2 reads "Run hard rules H1-H10." The note is present, but the range is wrong. (HEAD of `skills/writing-dag-plans/plan-quality.md` line 105 reads H1-H11, so a later commit changed it. As delivered in this commit, it does not match the spec.)
Fix: In `/home/user/parallel-dag-execution/skills/writing-dag-plans/plan-quality.md`, §Detection algorithm step 2, change "H1-H10" to "H1-H11". Keep the H10 member-index note as it is.

I traced the Step 8 acceptance gate only for the two new fixtures. I did not trace H10 against the existing should-pass fixtures, since those are outside the permitted file list.
