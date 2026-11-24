---
description: Write a design superspec charter when a brainstorm has found several projects
---

Write a **design** superspec charter for the work described in: $ARGUMENTS

Use this when brainstorming has found several projects that share contracts or an order, before any of them has a spec. The charter owns the decomposition and the decisions that cross children; each child still gets its own spec, brainstormed one at a time, and its own gates.

1. Start from `skills/writing-dag-plans/superspec-charter.md` with `charter_kind: design`. Keep the design-only section (Per-child scope) and the optional ones that have content; delete the rest.
2. Fill the Children table (ids, owner, `depends on`, `ships alone`; leave `plan` blank until a child has a plan) and list the same ids in `children:`. Give every contract one owning child.
3. Record cross-child decisions under Frozen decisions with their reasons, and questions nobody owns under Open gaps.
4. Save it as `docs/superpowers/specs/YYYY-MM-DD-<topic>-charter.md` (override per project preference).
5. From the user's repository, run `sh <plugin root>/skills/writing-dag-plans/plan-state charter <saved path>` and fix everything it prints. It reads the saved file, so it runs after step 4.
6. Tell the user which child to brainstorm first: one whose dependencies are all satisfied.

If `$ARGUMENTS` is empty, use the brainstorm in this conversation. If no brainstorm has found more than one project, say so and stop: a single project needs a spec, not a charter.
