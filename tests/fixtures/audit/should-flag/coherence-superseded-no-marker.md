<!--
FIXTURE: coherence-superseded-no-marker
LENS: coherence (spec)
EXPECTED: BLOCKING
COVERS: §2 and §5 name the UI location as `apps/modules/admin`. §9, ~60 lines
  later, overrides it to `apps/reporting/reporting-engine-ui` — with no marker at
  either earlier point of claim. A reader who stops at §2 or §5 builds in the
  wrong app.
EXPECTED REPORT (substring match):
  supersed
  no marker at the point of claim
MUST NOT REPORT: whether either location is the better choice (that is `design`),
  or whether those directories exist (that is `grounding`).
ASSUMES: nothing about the host repo.

ALSO PRESENT, scoreable for other lenses (found 2026-07-29 by `absence`,
`ambiguity`, and `design` during a wiring run, undeclared until then):
  - CLONE has no create path. §1 promises "browse, clone, and archive"; §3 commits
    to `GET` + `PATCH /:id` and "No new endpoints". A PATCH cannot create a row, so
    the capability is unimplementable as written — and one available reading
    (PATCH on the SOURCE id) corrupts the rule being cloned. §4 lists two screens,
    neither a clone affordance. Expected at BLOCKING from `absence` or `ambiguity`;
    DEFERRED from `design` is also correct, since design alone cannot name the
    concrete failure — that combination is a valid reconciler promotion.
  - AUTHORIZATION is stated nowhere. §2's only auth statement is delegation
    ("reuses the admin app's … auth wiring"); §9 moves the page to an
    embed-token-authenticated host; §8 says "Open questions: None." Expected at
    DEFERRED — the runtime failure chain needs embed-token audience semantics,
    which `ASSUMES: nothing about the host repo` puts out of reach. A lens
    proposing BLOCKING here is not wrong, but the reconciler should downgrade it
    with a probe.

A fixture scores only the lens named in `LENS:`. Other lenses run against it are
exercising the harness, not being graded — unless their finding appears above.
-->

---
title: rule-library UI placement
created: 2026-07-29
---

# Internal calc-rule library UI

## 1. Goal

Give internal staff a UI to browse, clone, and archive calculation rules.

## 2. Placement

The UI ships as a page in **`apps/modules/admin`**, routed at `/rules`. It reuses
the admin app's existing shell and auth wiring.

## 3. Data

Rules are read through `GET /api/rules` and written through
`PATCH /api/rules/:id`. No new endpoints.

## 4. Screens

A list view with filter chips, and an editor drawer for one rule.

## 5. Layer map

| Layer | Location |
|---|---|
| UI page | `apps/modules/admin/src/app/pages/rules/` |
| API | `apps/api/src/rules/` |
| Contracts | `libs/shared/module-contracts/src/lib/rules/` |

## 6. Copy

Archive confirmation reads "Archive this rule? It will stop applying to new
periods."

## 7. Out of scope

Un-archive. There is no inverse endpoint.

## 8. Open questions

None.

## 9. Addendum — placement decision (2026-07-29)

After review, the UI will be **embedded in
`apps/reporting/reporting-engine-ui`** instead, because that app already carries
the embed-token auth path this feature needs and the admin app does not.
