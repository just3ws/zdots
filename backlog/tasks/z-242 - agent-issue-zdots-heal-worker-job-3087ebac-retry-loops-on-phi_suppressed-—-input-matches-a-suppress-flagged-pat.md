---
id: Z-242
title: >-
  [agent-issue] zdots-heal: worker job 3087ebac retry-loops on phi_suppressed —
  input matches a suppress-flagged pat
status: Done
assignee: []
created_date: '2026-07-21 15:55'
updated_date: '2026-07-28 17:22'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 119895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `262025207aeb723c5f1b68236fc119cd`

zdots-heal: worker job 3087ebac retry-loops on phi_suppressed — input matches a suppress-flagged pattern and the job is requeued indefinitely. Needs: review whether the pattern hit is a true positive for this source, and a dead-letter/permanent-failure state so suppress-flagged jobs stop retrying. (Content not inspected — deny-list respected.)

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-07-28: resolved by the dead-letter state — job 3087ebac is status=dead at attempts=5 (retry cap now enforced); no jobs in retry-loop (queue: 680 completed / 26 dead / 0 pending). Residual: whether the phi_suppressed hit is a true positive for that source is operator judgment (content deny-listed); the docs_sync failure family stays tracked in Z-228/Z-225.
<!-- SECTION:NOTES:END -->
