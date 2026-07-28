---
id: Z-225
title: >-
  [agent-issue] docs_sync jobs die with 'invalid byte sequence in US-ASCII' —
  worker AI pipeline needs encoding norm
status: Done
assignee: []
created_date: '2026-07-15 04:53'
updated_date: '2026-07-28 18:47'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 104895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `530d0b7d6da7779a52c455797cfe3586`

docs_sync jobs die with 'invalid byte sequence in US-ASCII' — worker AI pipeline needs encoding normalization (UTF-8 scrub) before inference; 2 deterministic dead jobs from 2026-06-17/20, retry-proof

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-07-28: fixed — docs_sync normalizes residue and doc text to UTF-8 (invalid/undef → replacement) at the job boundary; launchd's US-ASCII default was the trigger. Spec covers the dirty-byte case. Worker restarted onto new code.
<!-- SECTION:NOTES:END -->
