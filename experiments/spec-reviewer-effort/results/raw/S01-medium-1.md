ISSUES

Requirement: Step 6 "rewire `depends_on:`" bullet must gain H9. The spec's replacement text is "On **rewire `depends_on:`**: run S1, S5, H9 on the updated DAG." The acceptance criteria repeat this ("rewire `depends_on:`" gains H9 in its list).
Actual: Commit c2c177d left this line unchanged. It still reads "- On **rewire `depends_on:`**: run S1, S5 on the updated DAG." (line 80 in that commit's file). The commit message claims H9 was added to rewire, but the diff has no such change.
Fix: In /home/user/parallel-dag-execution/skills/updating-dag-plans/SKILL.md, change that line to "- On **rewire `depends_on:`**: run S1, S5, H9 on the updated DAG." Do not change anything else.

Everything else is met at c2c177d, checked against that commit's file, not the current working tree:
- The new Hard rules bullet is present and matches the spec text exactly.
- The "add task" line says "run hard rules H1-H9 (was H1-H6)" and includes S1, S5, S8.
- The "modify body" line says "run H1, H2, H4, H5, H9 (was H1, H2, H4, H5)" and includes S2-S4, S6, S8.
- The Required reading line now cites "Hard rules H1-H9 and soft heuristics S1-S8". The stale "H1-H6" text no longer appears.
- I found no over-build. The diff touches only these lines.
- Four of the five grep verifications pass. The fifth (the "!" negated check) was not checked against the commit's file as a separate step, but "H1-H6" is absent from the working-tree file.
- No grep covers the rewire line, so this miss isn't caught by the listed verifications.
