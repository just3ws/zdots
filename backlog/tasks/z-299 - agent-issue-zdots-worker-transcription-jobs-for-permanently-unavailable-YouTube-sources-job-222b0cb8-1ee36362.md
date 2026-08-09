---
id: Z-299
title: >-
  [agent-issue] zdots-worker: transcription jobs for permanently-unavailable
  YouTube sources (job 222b0cb8, 1ee36362
status: To Do
assignee: []
created_date: '2026-08-08 22:07'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 174895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `60ae42c257383c0d1f1953df6ff769ca`

zdots-worker: transcription jobs for permanently-unavailable YouTube sources (job 222b0cb8, 1ee36362 — video removed/private, yt-transcribe exits 1 with 'Video unavailable') are retried indefinitely (10+ retries each in pipeline-events.jsonl) instead of being dead-lettered after N failures. Wastes worker cycles on unrecoverable jobs. Needs max-retry/dead-letter handling in the job queue for permanent (non-transient) failures.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
