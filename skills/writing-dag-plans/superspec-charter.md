---
id: superspec-charter-{{slug}}
title: "{{title}}"
type: superspec-charter
charter_kind: delivery   # delivery | design (see "Two kinds" below)
created: {{date}}
children: [{{child-id}}, {{child-id}}]   # the ids in the Children table, in build order
---

<!-- Two kinds of superspec charter. Pick one and delete the sections the other kind owns.

     DELIVERY charter — written at planning time over ONE approved spec that fans out into
     several plans. Thin: connective tissue only (decomposition, contracts, shared invariants,
     build order). No child detail; that lives in each child's plan.

     DESIGN charter — written during design, when a brainstorm finds several projects before
     any spec exists. It owns the decomposition and the decisions that cross children. Each
     child still gets its own spec; the charter says what each child covers, not how.

     Use a charter only when ~3+ interlocking pieces share invariants or interfaces. For
     single-piece work skip it (one spec -> one plan). Children run in parallel where the
     contracts allow: a child starts when the contracts it consumes have merged. -->

# {{title}}

## Intent
<!-- one paragraph + link to the intent brief or the brainstorm -->

## Children
<!-- One row per child, in build order. `children:` in the frontmatter lists the same ids.
     This table does NOT hold status: a child's status comes from its plan's task statuses,
     so it cannot drift from what actually ran.
     plan        — path to the child's plan. A child delivered by another plan's tasks names
                   them as `<plan path>#<task-id>, ...`. Blank until the plan exists.
     owner       — who is accountable for the child.
     depends on  — child ids or contract ids (C1, ...). Name a contract when the child needs
                   only part of another child; that is a partial dependency.
     ships alone — yes | held until <child or contract> | dark (merged but not reachable) -->
| id | child | plan | owner | depends on | ships alone |
|----|-------|------|-------|------------|-------------|

## Contracts between children
<!-- What crosses the seams: shared types, data shapes, API contracts. Each contract has
     exactly ONE owning child, which builds it; consumers depend on the contract id.
     Highest-value section of a superspec charter. -->
| id | contract | owner | consumers |
|----|----------|-------|-----------|

## Shared invariants
<!-- cross-child guarantees that, if two children disagreed, would break the feature silently -->

## Build order
<!-- why the order in the Children table is what it is; the accepted partial states between
     merges (what is true of the system while only some children have landed) -->

## Per-child scope (design charter only)
<!-- what each child covers and what it explicitly leaves to another child. Not its design:
     that is the child's spec. -->

## Frozen decisions (optional)
<!-- decisions made here that children and audits must not re-litigate, each with its reason -->

## Open gaps (optional)
<!-- governance or design questions nobody owns yet, each with who must decide -->
