ISSUES

Requirement: Step 6 "rewire `depends_on:`" bullet must gain H9. The spec gives the line as "On **rewire `depends_on:`**: run S1, S5, H9 on the updated DAG." The acceptance criteria repeat this ("rewire `depends_on:`` gains H9 in its list").
Actual: Commit c2c177d leaves that line unchanged as "- On **rewire `depends_on:`**: run S1, S5 on the updated DAG." The commit message claims H9 was added to rewire, but the diff has no such change.
Fix: In /home/user/parallel-dag-execution/skills/updating-dag-plans/SKILL.md, change that line to "- On **rewire `depends_on:`**: run S1, S5, H9 on the updated DAG." Touch nothing else.

Everything else is met:
- The new Hard rules bullet is present verbatim.
- The "add task" and "modify body" step 6 lines match the spec.
- Required reading now says H1-H9 / S1-S8, and the stale H1-H6 text is gone.
- All five grep verifications pass against the content at c2c177d. They fail on current HEAD only because later commits edited the file.
- No other content in the file was changed.
