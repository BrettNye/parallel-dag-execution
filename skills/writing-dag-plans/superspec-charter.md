---
id: superspec-charter-{{slug}}
title: "{{title}}"
type: superspec-charter
created: {{date}}
---

<!-- A THIN charter: connective tissue ONLY — decomposition, interfaces between pieces,
     shared invariants, build order. NO child detail (that lives in each child's spec).
     Use ONLY when ~3+ interlocking pieces share invariants/interfaces; for single-piece
     work skip this (one spec -> one plan). Pull children ONE AT A TIME. -->

# {{title}}

## Intent
<!-- one paragraph + link to the intent brief -->

## Decomposition — the children
<!-- one line each: id + what it is. No internal detail, no ordering (the status table owns order). -->

## Interfaces / contracts between pieces
<!-- what crosses the seams: shared types, data shapes, API contracts. Also the home for any
     decision with cross-child impact. Highest-value section of a charter. -->

## Shared invariants
<!-- cross-child guarantees that, if two children disagreed, would break the feature silently -->

## Build order
<!-- the dependency DAG between children; note any accepted partial states -->

## Child status
<!-- single source of truth for what's in flight, in build order -->
| id | child | status | order |
|----|-------|--------|-------|
