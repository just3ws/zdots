---
id: Z-006
title: Implement Distributed Tracing and Traceparent Propagation
status: To Do
assignee: []
created_date: '2026-03-26 15:17'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Evolve shell observability into a full distributed tracing control plane. This includes W3C Trace Context (traceparent) generation, propagation via shell hooks, and a modular OTLP-compatible collector toggle.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Derive/Generate W3C-compliant traceparent during session initialization
- [ ] #2 Update traceparent (span ID) for every shell command (preexec hook)
- [ ] #3 Implement curl wrapper to automatically inject 'traceparent' header
- [ ] #4 Create providers/trace/otlp.zsh to send spans to a local OTel collector
- [ ] #5 Add toggle (ZDOTS_TRACE_ENABLED) to enable/disable external telemetry
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
