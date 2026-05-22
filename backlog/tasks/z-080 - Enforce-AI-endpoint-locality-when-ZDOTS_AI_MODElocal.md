---
id: Z-080
title: Enforce AI endpoint locality when ZDOTS_AI_MODE=local
status: To Do
assignee: []
created_date: '2026-05-22 23:47'
labels:
  - phi
  - security
  - ai-boundary
milestone: m-5
dependencies:
  - Z-077
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ZDOTS_AI_MODE=local is currently advisory — nothing prevents a misconfigured ZDOTS_AI_ENDPOINT from routing requests to a cloud host. Before any inference request is dispatched, assert that the endpoint resolves to a loopback address (127.x) or RFC-1918 range (10.x, 172.16-31.x, 192.168.x). Hard exit with a clear error if the assertion fails. This is a shared function used by ai-query and zdots-ctx; not a warning, not a log entry — a hard block. PHI boundary enforcement depends on this gate being closed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Shared function zdots_assert_local_endpoint in lib/zdots/ai_boundary.sh (or equivalent) validates the host portion of ZDOTS_AI_ENDPOINT against loopback + RFC-1918 ranges
- [ ] #2 ai-query calls the assertion before dispatching any request when ZDOTS_AI_MODE=local
- [ ] #3 zdots-ctx calls the assertion before any inference operation when ZDOTS_AI_MODE=local
- [ ] #4 A non-local endpoint with ZDOTS_AI_MODE=local exits non-zero with message referencing ZDOTS_AI_ENDPOINT and ZDOTS_AI_MODE
- [ ] #5 ZDOTS_AI_MODE=cloud bypasses the locality check (explicit opt-in)
- [ ] #6 ZDOTS_AI_MODE=none bypasses entirely (no endpoint used)
- [ ] #7 Bats test: local endpoint passes, public IP fails, RFC-1918 LAN IP passes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
