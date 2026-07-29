<!--
FIXTURE: clean-frozen-decision-not-relitigated
LENS: any (spec) — run `design` and `charter` against it at minimum
EXPECTED: no finding
COVERS: silence as the correct answer, three ways.
  (1) §2's placement is recorded in `## Decisions` with its reason. A lens may
      challenge it ONLY with new grounded evidence that it is factually wrong —
      not because it would have chosen differently. There is no such evidence here.
  (2) The unknown field name in §3 is already listed under
      `## Empirical unknowns` with an owning probe task. Re-flagging a listed
      unknown is not a finding.
  (3) §4's duplication is explicitly accepted as DEFERRED in the audit record. A
      re-audit must not re-report it.
EXPECTED REPORT (substring match):
  No blocking findings
MUST NOT REPORT: a better placement than §2's; the unknown in §3; the duplication
  in §4. Any of those is a failed fixture — this is the churn the design exists to
  eliminate.
ASSUMES: nothing about the host repo. Lenses should verify what they can and
  report UNVERIFIABLE rather than manufacturing a finding.
-->

---
title: rule library UI (clean)
created: 2026-07-29
---

# Internal calc-rule library UI

## Decisions

- **DECIDED:** the UI embeds in `apps/reporting/reporting-engine-ui`, not a module
  app — because that app already carries the embed-token auth path this feature
  requires and a module app would need it built from scratch — 2026-07-29
- **DECIDED:** archived rules are hidden rather than deleted, because period
  recalculation must remain reproducible for closed periods — 2026-07-29

## Empirical unknowns

- Exact `field_name` of the rule-category custom field — not resolvable by
  reading; needs a query against live data. **Owner: task-probe-category-field.**

## 1. Goal

Give internal staff a UI to browse, clone, and archive calculation rules.

## 2. Placement

Embedded in `apps/reporting/reporting-engine-ui` at `/rules`, per the Decisions
ledger above.

## 3. Category filter

Rules carry a category sourced from a custom field whose exact `field_name` is not
yet known (see Empirical unknowns). The name ships as a single named constant so
the probe task has exactly one site to update.

## 4. Accepted duplication

The one-decimal hour formatter is defined in both renderers rather than shared.
Both live in the same runtime with an import path available, so a future
consolidation is cheap and no drift is silent. Accepted as deferred.

## 5. Acceptance criteria

- The list renders one row per non-archived rule.
- Archiving a rule removes it from the list without deleting it.
- Cloning opens the editor pre-filled, with a new id.

## 6. Out of scope

Un-archive — there is no inverse endpoint.

## Audit record

- **2026-07-29** · rev `a1b2c3d` · lenses: absence, ambiguity, grounding, charter,
  coherence, design · **READY — 0 blocking**
  - Deferred, accepted: duplicated hour formatter (§4) — same runtime, shared
    import available, no silent drift
  - Empirical unknowns opened: rule-category `field_name` → task-probe-category-field
