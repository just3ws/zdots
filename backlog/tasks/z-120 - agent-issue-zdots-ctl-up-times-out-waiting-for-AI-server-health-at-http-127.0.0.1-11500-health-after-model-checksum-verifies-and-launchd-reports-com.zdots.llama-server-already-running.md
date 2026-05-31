---
id: Z-120
title: >-
  [agent-issue] zdots-ctl up times out waiting for AI server health at
  http://127.0.0.1:11500/health after model checksum verifies and launchd
  reports com.zdots.llama-server already running
status: To Do
assignee: []
created_date: '2026-05-31 01:38'
updated_date: '2026-05-31 15:34'
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
