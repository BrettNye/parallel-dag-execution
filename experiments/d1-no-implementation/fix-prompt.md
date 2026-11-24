You are fixing one DAG plan after its gate-2 audit. Work only in the current repository.

Plan: {plan}
Audit findings: the plan's `## Audit record` section, and
`docs/superpowers/plans/.audit/{planname}/reconciliation.md` (the reconciled verdict,
blocking findings and recommended joint resolutions). The lens reports beside it are
background; the reconciliation decides.

Apply the resolution of every BLOCKING finding. Also apply any deferred item the
reconciliation says belongs in the plan's acceptance criteria. Make no other changes.
Keep the `## Audit record` section as it is. Do not read any other plan.
{arm_rule}
Then run `sh skills/writing-dag-plans/plan-state render {plan}` and
`sh skills/writing-dag-plans/plan-state check {plan}`; `check` must print nothing.

Do not commit. Report: each blocking finding and what you changed for it, any deferred
item you applied, and the plan-state result.
