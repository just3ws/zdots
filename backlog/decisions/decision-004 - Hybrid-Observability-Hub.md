---
id: decision-004
title: "Hybrid Observability Hub (Bare Metal -> Colima)"
date: '2026-03-27 10:20'
status: Accepted
---

## Context
A shell environment must be lightweight, but an observability hub (LGTM) is resource-heavy. Running Loki/Tempo/Grafana directly on the host consumes significant VRAM and cycles.

## Decision
Adopt a hybrid multi-hop routing architecture for telemetry.

1. **Host Entry**: A bare metal OTel Collector (`otelcol-contrib`) runs on the host, listening on port 4318. This provides the lowest possible latency for shell instrumentation.
2. **Central Hub**: Grafana LGTM stack runs in Colima (Docker) to keep the resource-heavy storage and UI isolated.
3. **Forwarding**: The bare metal collector buffers and forwards spans to the Colima hub via a dedicated OTLP port (4418).

## Consequences

**Positive:**
- **Performance**: Zero shell lag due to local OTLP/HTTP ingest.
- **Isolation**: LGTM stack can be easily restarted or rebuilt without affecting the host environment.
- **Unified Vision**: Provides a single Grafana dashboard for the shell, apps, and agents.

**Negative:**
- **Port Management**: Requires managing two OTLP ports (4318 for entry, 4418 for forwarding).
