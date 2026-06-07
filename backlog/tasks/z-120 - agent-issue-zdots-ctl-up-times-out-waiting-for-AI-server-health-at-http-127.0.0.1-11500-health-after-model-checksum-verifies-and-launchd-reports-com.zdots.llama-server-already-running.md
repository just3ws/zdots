---
id: Z-120
title: >-
  [agent-issue] zdots-ctl up times out waiting for AI server health at
  http://127.0.0.1:11500/health after model checksum verifies and launchd
  reports com.zdots.llama-server already running
status: Done
assignee: []
created_date: '2026-05-31 01:38'
updated_date: '2026-06-07 16:49'
labels:
  - agent-reported
  - bug
dependencies: []
priority: high
ordinal: 11890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** bug
**Priority:** high
**Trace ID:** `7c960417347f35ca73f21d9f5c063687`

zdots-ctl up times out waiting for AI server health at http://127.0.0.1:11500/health after model checksum verifies and launchd reports com.zdots.llama-server already running

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Recovery Notes

<!-- SECTION:RECOVERY:BEGIN -->
Follow-up isolation recovered the live platform without changing service
internals:

- `zdots-ctl reset` reproduced the AI health timeout.
- Direct `curl http://127.0.0.1:11500/health` later returned `{"status":"ok"}`.
- `zsvc restart postgres` and `zsvc restart redis` required launchctl access outside
  the agent sandbox, then direct probes passed.
- `zsvc restart colima` recovered the Docker runtime and LGTM stack.
- Outside the sandbox, `zdots-ctl status` reported all seven services green.
- `bats tests/platform_e2e.bats` passed 22/22 after recovery.

Likely instability boundary: manager health checks and sandboxed loopback/
launchctl probes can report false negatives while the host services are healthy.
The original `zdots-ctl up` timeout is still worth reviewing because the AI
server was launchd-running and socket-listening before HTTP readiness completed.
<!-- SECTION:RECOVERY:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause: start_llama was fire-and-forget — returned at launchd 'running' while the GGUF was still loading, so cmd_up's fatal 60s /health probe raced a slow cold load under memory pressure. Fix cb73fa2: start_llama blocks on _wait_inference; budget via ZDOTS_AI_WAIT (default 90); cmd_up uses non-fatal _wait_for_soft + diagnose hint. Verified: llama-ctl restart reports readiness wait (16s), zdots-ctl up clean, :11500 health 200.
<!-- SECTION:NOTES:END -->
