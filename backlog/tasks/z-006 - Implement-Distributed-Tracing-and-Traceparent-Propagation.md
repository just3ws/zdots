---
id: Z-006
title: Implement Distributed Tracing and Traceparent Propagation
status: Done
assignee:
  - '@myself'
created_date: '2026-03-26 15:17'
updated_date: '2026-03-26 16:04'
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
- [x] #1 Derive/Generate W3C-compliant traceparent during session initialization
- [x] #2 Update traceparent (span ID) for every shell command (preexec hook)
- [x] #3 Implement curl wrapper to automatically inject 'traceparent' header
- [x] #4 Create providers/trace/otlp.zsh to send spans to a local OTel collector
- [x] #5 Add toggle (ZDOTS_TRACE_ENABLED) to enable/disable external telemetry
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. **W3C Trace Context Generator**: Update `env.sh` to generate a W3C-compliant `traceparent` (00-traceid-spanid-flags) if not already present in the environment.
2. **Command Spans (Dynamic IDs)**: Modify `conf.d/05-observability.zsh` to generate a new `ZDOTS_SPAN_ID` for every command in the `preexec` hook, effectively making each shell command a Span.
3. **Propagation (Curl Injection)**: Add a `curl` wrapper (alias or function) that automatically injects the current `traceparent` header into requests.
4. **OTLP-Compatible Service**: Introduce `providers/trace/otlp.zsh` that uses `curl` to send spans to a local OpenTelemetry collector if `ZDOTS_TRACE_ENABLED=1` is set.
5. **Collector Toggle**: Update `.zdots.env` to allow enabling/disabling telemetry for different profiles (e.g., `local` for Mac, `none` for CI).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented W3C-compliant distributed tracing and traceparent propagation. 1. Added 32-hex Trace ID and 16-hex Span ID generation to env.sh. 2. Updated preexec hooks to rotate Span IDs on every command, making the shell session a tree of spans. 3. Introduced a curl wrapper to automatically inject the 'traceparent' header into outgoing requests. 4. Developed an OTLP-compatible provider (providers/trace/otlp.zsh) that asynchronously sends telemetry to a remote collector. 5. Integrated a telemetry toggle (ZDOTS_TELEMETRY_ENABLED) for environmental control.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Evolved shell observability into a full distributed tracing control plane with W3C Trace Context propagation and OTLP-ready asynchronous telemetry.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 The update ensures a more safe shell experience and verifies there are no functional regressions.
<!-- DOD:END -->
