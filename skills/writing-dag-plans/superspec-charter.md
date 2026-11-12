---
id: superspec-charter-{{slug}}
title: "{{title}}"
type: superspec-charter
created: {{date}}
---

<!-- A THIN superspec charter: connective tissue ONLY — decomposition, interfaces between
     pieces, shared invariants, build order. NO child detail (that lives in each child's spec).
     Use ONLY when ~3+ interlocking pieces share invariants/interfaces; for single-piece
     work skip this (one spec -> one plan). Children run in parallel where the contracts
     allow: a child starts when the contracts it consumes have merged. -->

# {{title}}

## Intent
<!-- one paragraph + link to the intent brief -->

## Decomposition — the children
<!-- one line each: id + what it is. No internal detail, no ordering (the child table owns order). -->

## Interfaces / contracts between pieces
<!-- what crosses the seams: shared types, data shapes, API contracts. Also the home for any
     decision with cross-child impact. Highest-value section of a superspec charter. -->

## Shared invariants
<!-- cross-child guarantees that, if two children disagreed, would break the feature silently -->

## Build order
<!-- the dependency DAG between children; note any accepted partial states -->

## Children
<!-- Lists the children and their order. It does NOT hold status: a child's status comes
     from its plan's task statuses, so it cannot drift from what actually ran. A child with
     no plan of its own (delivered by tasks of another plan) names those tasks in `plan`
     instead of a plan file. -->
| id | child | plan | order |
|----|-------|------|-------|
