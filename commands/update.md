---
description: Update a DAG plan mid-flight (mutates only pending/ready tasks)
---

Invoke the `updating-dag-plans` skill on the plan file: $ARGUMENTS

If `$ARGUMENTS` is empty, ask the user which plan file to update. The skill will only mutate tasks whose `status:` is `pending` or `ready`. Tasks in `running`, `done`, `failed`, or `skipped` are immutable history and cannot be modified.
