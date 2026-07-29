---
description: Audit a spec with parallel lenses before planning (gate 1)
---

Invoke the `auditing-artifacts` skill at **gate 1** on the following spec: $ARGUMENTS

If `$ARGUMENTS` is empty, ask which spec to audit. If it names a file, read it;
otherwise treat it as a topic and locate the matching spec under the repo's specs
directory.

Use the spec lens set (`./lenses-spec.md` — all six lenses unless the user named a
subset), dispatch them in one message, then reconcile.

Pass `--full` through if present, to force a whole-artifact re-audit instead of a
diff-scoped one.

Do not fix the findings as part of this command. Report the verdict, record the
audit in the artifact, and let the author decide — applying a cluster's joint
resolution is a separate, deliberate step.
