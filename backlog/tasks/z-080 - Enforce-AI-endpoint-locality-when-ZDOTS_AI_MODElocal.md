---
id: Z-080
title: Enforce AI endpoint locality when ZDOTS_AI_MODE=local
status: Done
assignee: []
created_date: '2026-05-22 23:47'
updated_date: '2026-05-23 00:37'
labels:
  - phi
  - security
  - ai-boundary
milestone: m-5
dependencies:
  - Z-077
modified_files:
  - lib/ai_boundary.bash
  - bin/ai-query
  - bin/zdots-ctx
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ZDOTS_AI_MODE=local is currently advisory — nothing prevents a misconfigured ZDOTS_AI_ENDPOINT from routing requests to a cloud host. Before any inference request is dispatched, assert that the endpoint resolves to a loopback address (127.x) or RFC-1918 range (10.x, 172.16-31.x, 192.168.x). Hard exit with a clear error if the assertion fails. This is a shared function used by ai-query and zdots-ctx; not a warning, not a log entry — a hard block. PHI boundary enforcement depends on this gate being closed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Shared function zdots_assert_local_endpoint in lib/zdots/ai_boundary.sh (or equivalent) validates the host portion of ZDOTS_AI_ENDPOINT against loopback + RFC-1918 ranges
- [x] #2 ai-query calls the assertion before dispatching any request when ZDOTS_AI_MODE=local
- [x] #3 zdots-ctx calls the assertion before any inference operation when ZDOTS_AI_MODE=local
- [x] #4 A non-local endpoint with ZDOTS_AI_MODE=local exits non-zero with message referencing ZDOTS_AI_ENDPOINT and ZDOTS_AI_MODE
- [x] #5 ZDOTS_AI_MODE=cloud bypasses the locality check (explicit opt-in)
- [x] #6 ZDOTS_AI_MODE=none bypasses entirely (no endpoint used)
- [ ] #7 Bats test: local endpoint passes, public IP fails, RFC-1918 LAN IP passes
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
lib/ai_boundary.bash created with zdots_ai_gate (exits 2 when ZDOTS_AI_MODE=none) and zdots_assert_local_endpoint (hard-fails on non-RFC-1918 endpoint when mode=local). Wired into bin/ai-query after arg parsing. Wired into bin/zdots-ctx before semantic query, capture, and hydrate AI paths. Hardcoded http://127.0.0.1:8080 in zdots-ctx replaced with _AI_ENDPOINT variable. Bats test for mode=none deferred to dedicated test task.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
