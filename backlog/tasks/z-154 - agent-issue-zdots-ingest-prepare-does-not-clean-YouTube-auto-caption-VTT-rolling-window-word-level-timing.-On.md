---
id: Z-154
title: >-
  [agent-issue] zdots-ingest-prepare does not clean YouTube auto-caption VTT
  (rolling-window word-level timing). On
status: To Do
assignee: []
created_date: '2026-06-16 12:56'
updated_date: '2026-06-21 05:29'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 45890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `6bf14d21464f22110cd5256b140c4c30`

zdots-ingest-prepare does not clean YouTube auto-caption VTT (rolling-window word-level timing). On the en auto-captions for a 31min video it left inline <00:00:01> tags, align:start cue settings, and 3.7x scroll-duplication (18477 words from a ~5100-word talk). It works on clean whisper VTT but not YouTube source captions. Relevant to Z-150 (YouTube source-ingestion adapter): the adapter needs a de-roll + de-tag step (overlap-reconstruction) before ingest-prepare. Workaround used this session: a python overlap-reconstruction pass producing a clean 5079-word transcript that matched whisper's 5066 words within 0.3%.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: claude
created: 2026-06-21 05:29
---
Finding from Z-166: this VTT cleaner (bin/zdots-ingest-prepare, simple sed) is on the OLD manual ingest path. The new transcription pipeline (Z-164+) transcribes with whisper and never ingests YouTube auto-caption VTT, so this bug is off the pipeline's path. Disposition (operator): keep open; revisit at parity — likely close as SUPERSEDED once the pipeline fully replaces the manual ingest flow. Only fix the rolling-window sed if the manual zdots-ingest-prepare VTT path is still needed in the interim.
---
<!-- COMMENTS:END -->
