You are fixing one DAG plan that `plan-state preflight` refused to run. Work only in the
current repository.

Plan: {plan}
Preflight output: `docs/superpowers/plans/.preflight-output.txt` (saved when the run halted).

Fix only the errors printed in that file. You may change only `files:` lists and the paths
cited in task text, and only as far as each printed error needs. Make no other change: no
new tasks, no new acceptance criteria, no edits to task bodies beyond the cited paths, and
no change to any task whose status is not pending or ready. Do not read any other plan, and
do not read any audit record.

Then run `sh skills/writing-dag-plans/plan-state check {plan}` (it must print nothing) and
`sh skills/writing-dag-plans/plan-state preflight {plan}` (it must exit 0; warnings may
remain).

Do not commit. Report each printed error, the change you made for it, and the two
plan-state results.
