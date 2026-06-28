---
id: Z-140
title: >-
  [agent-issue] zsvc status embed reports healthy=false/http_healthy=false while
  semantic zdots-ctx query succeeds against the embed service after restart
status: Done
assignee: []
created_date: '2026-06-09 18:25'
updated_date: '2026-06-28 22:47'
labels:
  - agent-reported
  - bug
  - wave4
dependencies: []
priority: medium
ordinal: 31890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** medium
**Trace ID:** `6112098e51f546e37392295b4b3f4790`

zsvc status embed reports healthy=false/http_healthy=false while semantic zdots-ctx query succeeds against the embed service after restart

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Investigated 2026-06-14 (sonnet agent died on session limit before reporting; Opus reviewed the uncommitted draft and verified against live service — NOT integrated). FINDINGS: embed /health (127.0.0.1:11501) returns HTTP 200 {"status":"ok"} when ready; the old probe 'curl -sf /health' is correct for that. Draft fix (in discarded worktree) accepted any /health body except 'loading model'/'error', on the theory that a busy single-slot server 503s on /health. UNVERIFIED PREMISE: in current llama.cpp the 'no slot available' 503 comes from /embedding, NOT /health — /health only reports model-load status. So the draft does NOT address the real symptom and behaves identically to curl -sf during the load window. LIKELY ROOT CAUSE: restart timing race — zsvc probes /health while the model is still loading (503 'loading model' → healthy=false), but the user's semantic query lands seconds later after load completes. NEXT STEP: add a post-restart readiness wait/retry (poll /health until 200 with a timeout) rather than loosening the health contract; reproduce by restarting embed and probing immediately. Do not loosen /health acceptance without confirming the actual busy-state response code+body.
<!-- SECTION:NOTES:END -->
