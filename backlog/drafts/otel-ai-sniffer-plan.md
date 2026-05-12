# Design Specification: OTel AI Sniffer

## Overview
This document outlines the architecture for integrating an AI-driven "Sniffer" into the local OpenTelemetry (OTel) stack. The goal is to intercept high-value telemetry (primarily traces) and use local AI to generate automated insights, such as root cause analysis for command failures or performance regression detection.

## Proposed Architecture: The "Sidecar Bridge"

We will use the **Sidecar Sniffer** approach. This isolates the AI processing from the core telemetry storage (LGTM) and prevents the AI analysis from blocking the primary data path.

### 1. Collector Configuration (`etc/otel-collector.yaml`)

We will duplicate the trace stream using a new OTLP exporter pointing to our local bridge.

```yaml
exporters:
  # ... existing exporters ...
  otlphttp/ai_bridge:
    endpoint: "http://127.0.0.1:4419" # Dedicated port for the AI Sniffer
    tls:
      insecure: true

processors:
  # Use the transform processor to filter out noise BEFORE hitting the bridge.
  # We only want to spend AI tokens on interesting events.
  transform/ai_filter:
    error_mode: ignore
    trace_statements:
      - context: span
        statements:
          # Keep spans that have errors
          - keep_keys(attributes, ["error"]) where status.code == 2
          # Keep slow operations (e.g., > 1000ms)
          - keep_keys(attributes, ["duration"]) where end_time_unix_nano - start_time_unix_nano > 1000000000

service:
  pipelines:
    traces/ai:
      receivers: [otlp]
      processors: [transform/ai_filter, batch]
      exporters: [otlphttp/ai_bridge]
```

### 2. The Sniffer Utility (`bin/otel-ai-bridge`)

A lightweight HTTP server (likely written in Bash using `nc` or a simple Python script, depending on complexity requirements) that acts as an OTLP receiver.

**Core Responsibilities:**
1.  **Receive:** Accept POST requests containing OTLP JSON data on port 4419.
2.  **Buffer:** Aggregate spans belonging to the same `trace_id` to form a complete picture of the operation.
3.  **Prompt Generation:** Format the trace data into a structured prompt suitable for an LLM (e.g., "Analyze this trace. The operation failed at step X. Identify the likely cause based on these attributes: ...").
4.  **Inference:** Dispatch the prompt to the local AI model (using `ai-query` or `llama-ctl` directly).
5.  **Output:** Display the AI insight. This could be written to a dedicated log file (`~/.local/state/zsh/ai-insights.log`) or pushed back into the shell environment via a notification mechanism if urgent.

### 3. Lifecycle Integration

The sniffer will be managed as a first-class service within the Zdots control plane.

*   **Manager:** A new script, `bin/otel-ai-bridge`, will use `lib/lifecycle.bash`.
*   **Startup:** `zdots-ctl up` will ensure the bridge is running alongside the collector.
*   **Status:** `zdots-ctl status` will report the bridge's health and processed event count.

## Phase 1 Deliverables (Prototype)

To validate this approach without over-engineering, the first phase should focus on:
1.  **The Filter:** Configuring the OTel Collector to only send Error spans to the bridge.
2.  **The Receiver:** A simple Python script that receives the JSON payload and prints it to a file.
3.  **The Analyst:** A bash recipe (`recipes/trace-analyze`) that takes a `trace_id`, reads the raw JSON from the receiver's log, formats it, and calls `ai-query` to summarize the error.

This allows us to evaluate the quality of the AI insights before building the complex buffering and automated dispatch logic.