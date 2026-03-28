---
id: decision-003
title: "Active Pulse Monitoring (Shell Heartbeat)"
date: '2026-03-27 10:15'
status: Accepted
---

## Context
Standard observability is passive; it tells us what happened. To ensure system-wide reliability and track "terminal availability," we need an active signal that the shell environment is correctly initialized and connected to the control plane.

## Decision
Implement a "Heartbeat" mechanism using `otel-cli`. Every time a Zsh session is initialized, it sends a backgrounded span named `shell.heartbeat` to the OTel collector.

1. **Instrumentation**: Added to `conf.d/05-observability.zsh`.
2. **Metadata**: Each heartbeat includes the environment profile and OS type.
3. **Asynchronous**: Execution is backgrounded (`&!`) to ensure zero impact on startup time.

## Consequences

**Positive:**
- **Availability Tracking**: We can now alert if a developer's environment hasn't seen a heartbeat in X days.
- **Connectivity Verification**: Confirms the OTLP pipeline is functional from the first moment of interaction.

**Negative:**
- **Telemetry Noise**: Adds one span per shell session, which can scale quickly in environments with many subshells. (Mitigated by only running in interactive mode).
