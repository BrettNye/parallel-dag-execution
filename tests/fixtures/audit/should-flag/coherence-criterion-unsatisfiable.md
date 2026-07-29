<!--
FIXTURE: coherence-criterion-unsatisfiable
LENS: coherence (spec)
EXPECTED: BLOCKING, reported as UNDECIDABLE AS WRITTEN
COVERS: §3 defines the displayed value as `row.owner ?? row.teamDefault` and says
  the editor pre-fills with the inherited text. §5 then requires that "clearing
  the field restores the inherited value". Clearing a pre-filled text editor
  yields '', and '' ?? default is '' — so inheritance can never be restored and
  the cell stays blank permanently. The spec never states that empty maps to null.
  The lens must NOT pick a side; it must force the author to choose.
EXPECTED REPORT (substring match):
  undecidable as written
MUST NOT REPORT: a chosen resolution presented as the answer. Guessing here is
  the failure mode — a guessed resolution becomes the next round's finding.
ASSUMES: nothing about the host repo.
-->

---
title: inline owner override
created: 2026-07-29
---

# Inline owner override on the roster table

## 1. Goal

Let a coordinator override the owner of a single roster row without leaving the
table.

## 2. Data model

`roster.owner` becomes nullable. Null means "inherit from the team default".

## 3. Display and edit

The Owner cell displays the **effective** value: `row.owner ?? row.teamDefault`.

The column is `editable: true` with `editorType: 'text'`. Editing an inherited
cell pre-fills the editor with the inherited text so the coordinator can see what
they are replacing. Confirming the edit PATCHes `{ owner: <value> }`.

## 4. Layer map

| Layer | Location |
|---|---|
| Table | `apps/web/src/app/roster/roster-table.component.ts` |
| API | `apps/api/src/roster/` |

## 5. Acceptance criteria

- The cell shows the team default when `owner` is null.
- An edit writes an explicit override.
- **Clearing the field restores the inherited value.**
- The column is not sortable.

## 6. Out of scope

Bulk owner reassignment.
