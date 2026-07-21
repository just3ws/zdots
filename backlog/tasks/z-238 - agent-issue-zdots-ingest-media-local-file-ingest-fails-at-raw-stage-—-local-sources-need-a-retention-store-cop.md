---
id: Z-238
title: >-
  [agent-issue] zdots-ingest-media: local-file ingest fails at raw stage —
  'local sources need a retention-store cop
status: To Do
assignee: []
created_date: '2026-07-21 13:20'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 117895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `2f902b70738550f801577f176ee86c12`

zdots-ingest-media: local-file ingest fails at raw stage — 'local sources need a retention-store copy at ingest time (not yet implemented)'. Job dies after retries; media_sources row left ingest_status=failed. Implement the retention-store copy path or reject local files with a clear up-front error.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
