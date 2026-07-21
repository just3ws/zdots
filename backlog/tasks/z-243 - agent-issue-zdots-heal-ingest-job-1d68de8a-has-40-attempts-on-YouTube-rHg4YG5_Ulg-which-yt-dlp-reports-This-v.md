---
id: Z-243
title: >-
  [agent-issue] zdots-heal: ingest job 1d68de8a has 40+ attempts on YouTube
  rHg4YG5_Ulg which yt-dlp reports 'This v
status: To Do
assignee: []
created_date: '2026-07-21 15:55'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 120895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `262025207aeb723c5f1b68236fc119cd`

zdots-heal: ingest job 1d68de8a has 40+ attempts on YouTube rHg4YG5_Ulg which yt-dlp reports 'This video is not available' — permanent upstream failure is retried forever. Worker needs permanent-vs-transient failure classification (same theme as Z-228 docs_sync retry-loop; yt-dlp strategy itself tracked in Z-237).

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
