---
id: platform-discovery
title: "OTel Platform Discovery Spec"
purpose: Standardizes how AI agents and external apps discover Zdots services.
rationale: Enables seamless integration of Gemini and other tools into the shell control plane.
---

# Zdots Platform Discovery Specification

This document defines the contract for external entities (AI agents, local microservices) to discover and interact with the Zdots control plane.

## 1. Environment Discovery

All Zdots-compatible processes should inspect the following environment variables to align with the active session:

| Variable | Type | Description |
| :--- | :--- | :--- |
| `ZDOTS_TRACE_ID` | Hex(32) | The current W3C Trace ID. |
| `ZDOTS_SPAN_ID` | Hex(16) | The Parent Span ID for child processes. |
| `TRACEPARENT` | String | Standard W3C Trace Context header value. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | URL | The active bare-metal collector endpoint (default: `http://localhost:4318`). |

## 2. Service Endpoints

The following local services are managed by the Zdots control plane:

| Service | Port | Protocol | Description |
| :--- | :--- | :--- | :--- |
| OTel Ingest (Host) | 4318 | OTLP/HTTP | High-performance host-based collector. |
| OpenObserve | 5080 | HTTP | Native backend + UI for logs/metrics/traces (o2.local). |
| OpenObserve gRPC | 5081 | OTLP/gRPC | OpenObserve OTLP ingest. |
| AI Inference | 11500 | HTTP | Local LLM service (llama.cpp). |
| AI Embeddings | 11501 | HTTP | Dedicated llama.cpp embedding service. |

## 3. Gemini OTLP Integration

Future Gemini-based tasks should bridge their internal telemetry into the Zdots graph by:
1.  Sourcing the `TRACEPARENT` from the shell session.
2.  Creating spans with `parentId` set to the shell's current `ZDOTS_SPAN_ID`.
3.  Reporting to the `OTEL_EXPORTER_OTLP_ENDPOINT`.

## 4. Alerting Contract

The `platform.health` span is sent by `bin/capabilities`. OpenObserve alerts should be configured to monitor:
- **`ai.status == 0`**: Local inference engine is offline.
- **`disk.avail < 500M`**: Extreme resource constraint.
- **`span.status == error`**: Contract violation detected in the environment.
