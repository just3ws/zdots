---
id: Z-127
title: Collapse the Platform Service into one deep module
status: Done
assignee: []
created_date: '2026-06-05 19:58'
updated_date: '2026-06-05 21:54'
labels:
  - architecture
  - refactor
dependencies: []
priority: high
ordinal: 18890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Architecture candidate #2 (Strong). CONTEXT.md names "Platform Service" as the umbrella concept, but no module embodies it — five scripts each re-derive health, status, and dispatch.

Files: bin/zsvc, bin/zdots-ctl, bin/llama-ctl, bin/otel-collector, bin/nginx-ctl, lib/svc-*.bash

Problem: three+ health-check implementations for the same endpoints (zsvc _svc_health_text, zdots-ctl _*_up probes, per-ctl health_*), duplicated --json status formatting, and hand-rolled dispatch `case` blocks per ctl. Adding the worker service (this session) required editing every one of these duplicated spots, confirming the friction firsthand.

Solution: a per-service descriptor (name/endpoint/probe/launch) behind one interface; lifecycle and probing live in the implementation, scripts become thin adapters.

Wins: locality (one health timeout, one place), leverage (a new service = one descriptor), interface-as-test-surface (probe a descriptor without a live service), deletes the duplicated dispatch case x5.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A service descriptor abstraction exists and at least two ctl scripts consume it
- [x] #2 Health/status/dispatch logic has one source of truth, not per-script copies
- [x] #3 zsvc and zdots-ctl derive service state from the descriptor
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
New lib/svc-registry.bash holds one descriptor per service (catalog + lifecycle verbs) plus zdots_svc_resolve / zdots_svc_managed / zdots_svc_state / zdots_svc_healthy. bin/zsvc (_svc_meta, ALL_SVCS, _svc_state_pid, _svc_health_text) and bin/zdots-ctl (_*_up probes + endpoints) both derive from it; zsvc's three duplicated state helpers were deleted.

Evidence:
- AC1: lib/svc-registry.bash consumed by bin/zsvc and bin/zdots-ctl (two scripts).
- AC2: zdots_svc_healthy (one liveness probe per service) and zdots_svc_state (one state probe) replace the per-script copies.
- AC3: zsvc derives ALL_SVCS/_svc_meta/state/health from the registry; zdots-ctl's _ai_up/_embed_up/_otel_up/_grafana_up/_colima_up/_ctx_up/_redis_up/_worker_up call zdots_svc_healthy.
- Behaviour-preserving: zsvc list, zsvc health (text+json), zdots-ctl status (text+json) byte-identical before/after (diff clean).
- tests/svc_registry.bats 9/9. make check exit=0 (489 bats tests, shellcheck --severity=warning clean).

Scope: tracer-bullet (per-ctl scripts llama-ctl/otel-collector/nginx-ctl remain the adapters the descriptor points to). Commit 5cb0d75, merged to main.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Service catalog + health/state probes unified in lib/svc-registry.bash; zsvc and zdots-ctl derive from it. Behaviour byte-identical; make check green. Per-ctl scripts left as adapters.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
