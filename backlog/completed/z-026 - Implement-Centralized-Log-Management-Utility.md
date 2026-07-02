---
id: Z-026
title: Implement Centralized Log Management Utility
status: Done
assignee: []
created_date: '2026-03-28 17:23'
updated_date: '2026-06-29 19:02'
labels:
  - wave1
milestone: m-2
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create bin/logs to provide a unified interface for tailing and searching all control plane logs (traces, collector logs, AI server output).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Create bin/logs with multi-tail support
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Superseded by zsvc log management. `zsvc logs all` multi-tails all registered logs; `zsvc logs all --paths` lists every log source; `zsvc logs <svc>` tails a single service. Creating bin/logs would be a shim around zsvc with no added value — all nine registered services (llama, embed, otel, o2, nginx, pg, redis, zdots-worker, zdots-statusd) already appear in `zsvc logs all --paths`. Closing as done-by-zsvc.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
