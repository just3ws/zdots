---
id: Z-240
title: >-
  [agent-issue] Retention-store GC: purging a media source leaves on-disk
  orphans. A source purge (DB delete of medi
status: To Do
assignee: []
created_date: '2026-07-21 16:10'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 119895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `2f902b70738550f801577f176ee86c12`

Retention-store GC: purging a media source leaves on-disk orphans. A source purge (DB delete of media_sources) does NOT reap either (1) the mid-keyed artifact dir ingest-sources/<mid>/ or (2) the new sha-keyed local retention copy ingest-sources/_local/<sha>.<ext> added in Z-238. Both must be removed by hand today. Implement retention-store GC so purge/reprocess-purge reaps both locations; consider a sweep for orphans with no matching media_sources row. Consistent with the pre-existing 'DB delete doesn't touch disk' gap. Related: Z-238.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
