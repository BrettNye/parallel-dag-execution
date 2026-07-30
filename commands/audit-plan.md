---
description: Audit a DAG plan with parallel lenses before execution (gate 2)
---

Invoke the `auditing-artifacts` skill at **gate 2** on the following plan: $ARGUMENTS

If `$ARGUMENTS` is empty, ask which plan to audit. Locate the plan's parent spec —
if it cannot be found, say so and audit coverage against what the plan claims to
deliver, noting the limitation.

**The spec is approved and frozen.** No lens may reopen a spec design decision;
this gate asks only whether the plan honors the spec and will execute safely.

Use the plan lens set (`./lenses-plan.md` — all seven lenses unless the user named
a subset), dispatch them in one message, then reconcile.

If the user asks which lenses are worth running — or is weighing the cost against just
executing — show them the overlap table in `auditing-artifacts` step 4. A plan from
`writing-dag-plans` has already passed H1–H11 and S1–S11, which largely cover
`dag-integrity` and `context-sufficiency` but do **not** touch `coverage` or
`coherence` at all. Do not narrow the set on your own judgement; give them the table
and let them choose.

Pass `--full` through if present, to force a whole-artifact re-audit instead of a
diff-scoped one.

Do not fix the findings as part of this command, and do not mutate any task that
is `running`, `done`, `failed`, or `skipped` — plan history is immutable. Report
the verdict, record the audit in the plan, and let the author decide.
