---
id: Z-127
title: Collapse the Platform Service into one deep module
status: To Do
assignee: []
created_date: '2026-06-05 19:58'
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
- [ ] #1 A service descriptor abstraction exists and at least two ctl scripts consume it
- [ ] #2 Health/status/dispatch logic has one source of truth, not per-script copies
- [ ] #3 zsvc and zdots-ctl derive service state from the descriptor
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
