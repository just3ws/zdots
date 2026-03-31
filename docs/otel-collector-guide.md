# Connecting to the Local OTel Collector

This machine runs a bare-metal OpenTelemetry Collector (`otelcol-contrib`) that accepts telemetry from any local application and forwards it to a central LGTM (Loki, Grafana, Tempo, Mimir) stack.

## Quick Start

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_SERVICE_NAME="your-service-name"
```

Set `OTEL_SERVICE_NAME` to your application's identity (e.g., `phalanx-server`, `my-api`). Each service must set its own name — the shell does NOT export a default.

**Important:** Always use `127.0.0.1`, not `localhost`. gRPC clients resolve `localhost` to IPv6 (`[::1]`) first, which fails on this setup.

## Endpoints

The collector accepts **OTLP/HTTP** on port `4318` for all three signal types:

| Signal  | URL                                | Destination        |
|---------|------------------------------------|--------------------|
| Traces  | `http://127.0.0.1:4318/v1/traces`  | Tempo via Grafana  |
| Metrics | `http://127.0.0.1:4318/v1/metrics` | Prometheus         |
| Logs    | `http://127.0.0.1:4318/v1/logs`    | Loki               |

---

## Sending Traces

Traces represent the lifecycle of a request or operation. Each trace contains spans with timing, attributes, and parent-child relationships.

### Using an OTel SDK (Recommended)

Most SDKs auto-instrument HTTP, database, and framework calls when configured with the endpoint:

**Node.js / TypeScript:**
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318 \
OTEL_SERVICE_NAME=my-node-app \
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

**Python:**
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318 \
OTEL_SERVICE_NAME=my-python-app \
opentelemetry-instrument python app.py
```

**Go:**
```go
exporter, _ := otlptracehttp.New(ctx,
    otlptracehttp.WithEndpoint("127.0.0.1:4318"),
    otlptracehttp.WithInsecure(),
)
```

**Rust:**
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318 \
OTEL_SERVICE_NAME=my-rust-app \
cargo run
```

### Using otel-cli (Shell Scripts / One-Off Spans)

```bash
OTEL_SERVICE_NAME=my-script \
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318 \
otel-cli span --name "deploy.run" --attrs "env=staging,version=1.2.3"
```

### Using curl (Manual / Testing)

```bash
curl -X POST http://127.0.0.1:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{"key": "service.name", "value": {"stringValue": "my-service"}}]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "abcdef1234567890abcdef1234567890",
          "spanId": "1234567890abcdef",
          "name": "my.operation",
          "startTimeUnixNano": "1700000000000000000",
          "endTimeUnixNano": "1700000001000000000",
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": 200}}
          ]
        }]
      }]
    }]
  }'
```

**View in Grafana:** Explore → Tempo → Search by service name or trace ID.

---

## Sending Metrics

Metrics represent measurements over time: counters, gauges, and histograms.

### Using an OTel SDK

The same `OTEL_EXPORTER_OTLP_ENDPOINT` env var configures metrics export alongside traces. Most SDKs export both when auto-instrumentation is enabled.

To control the export interval:
```bash
export OTEL_METRIC_EXPORT_INTERVAL=5000  # milliseconds (default: 60000)
```

### Using curl (Manual / Testing)

```bash
curl -X POST http://127.0.0.1:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [{"key": "service.name", "value": {"stringValue": "my-service"}}]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http.request.duration",
          "unit": "ms",
          "histogram": {
            "dataPoints": [{
              "startTimeUnixNano": "1700000000000000000",
              "timeUnixNano": "1700000060000000000",
              "count": "150",
              "sum": 4500.0,
              "bucketCounts": ["10", "50", "60", "20", "10"],
              "explicitBounds": [10, 50, 100, 500]
            }],
            "aggregationTemporality": 2
          }
        }]
      }]
    }]
  }'
```

**Gauge example** (current value, e.g., queue depth):
```bash
curl -X POST http://127.0.0.1:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [{"key": "service.name", "value": {"stringValue": "my-service"}}]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "queue.depth",
          "unit": "1",
          "gauge": {
            "dataPoints": [{
              "timeUnixNano": "1700000000000000000",
              "asInt": "42"
            }]
          }
        }]
      }]
    }]
  }'
```

**View in Grafana:** Explore → Prometheus → Query by metric name (e.g., `http_request_duration`).

---

## Sending Logs

Logs are structured or unstructured text records with severity, timestamp, and optional trace correlation.

### Using an OTel SDK

OTel log bridges connect your existing logger (e.g., Winston, Pino, Python `logging`, `slog`) to the collector. Logs are automatically correlated with the active trace context.

**Node.js** (Pino + OTel bridge):
```javascript
const { logs } = require('@opentelemetry/api-logs');
// With auto-instrumentation enabled, Pino logs are bridged automatically
```

**Python:**
```python
from opentelemetry._logs import set_logger_provider
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter

provider = LoggerProvider()
provider.add_log_record_processor(
    BatchLogRecordProcessor(OTLPLogExporter(endpoint="http://127.0.0.1:4318/v1/logs"))
)
set_logger_provider(provider)

import logging
logging.basicConfig(level=logging.INFO)
logging.info("This log is sent to the collector")
```

### Using curl (Manual / Testing)

```bash
curl -X POST http://127.0.0.1:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [{"key": "service.name", "value": {"stringValue": "my-service"}}]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "1700000000000000000",
          "severityNumber": 9,
          "severityText": "INFO",
          "body": {"stringValue": "User login successful"},
          "attributes": [
            {"key": "user.id", "value": {"stringValue": "u-12345"}},
            {"key": "http.method", "value": {"stringValue": "POST"}}
          ]
        }]
      }]
    }]
  }'
```

**Severity levels:** TRACE=1, DEBUG=5, INFO=9, WARN=13, ERROR=17, FATAL=21.

**Correlating logs with traces:** Add `traceId` and `spanId` fields to the log record and they'll link automatically in Grafana:
```json
{
  "timeUnixNano": "1700000000000000000",
  "severityNumber": 9,
  "severityText": "INFO",
  "body": {"stringValue": "Processing request"},
  "traceId": "abcdef1234567890abcdef1234567890",
  "spanId": "1234567890abcdef"
}
```

**View in Grafana:** Explore → Loki → Query by service or severity. Correlated logs appear alongside traces in the Tempo trace view.

---

## What Happens to Your Telemetry

The collector routes all signals through a batch processor, then to three exporters:

```
Your App ──OTLP/HTTP──→ Collector (127.0.0.1:4318)
                            ├──→ Debug (collector log file)
                            ├──→ File  (collector-traces.json, 10MB rotation)
                            └──→ LGTM  (gRPC → 127.0.0.1:4417)
                                    ├──→ Tempo (traces)
                                    ├──→ Loki (logs)
                                    └──→ Prometheus (metrics)
```

## Viewing Your Data

- **Grafana:** http://127.0.0.1:3000 (default credentials: `admin` / `admin`)
  - **Traces:** Explore → Tempo datasource → Search by service name or trace ID
  - **Logs:** Explore → Loki datasource → `{service_name="my-service"}`
  - **Metrics:** Explore → Prometheus datasource → Query by metric name
  - **Correlations:** Clicking a trace ID in Loki jumps to the trace in Tempo, and vice versa

## Lifecycle

| Component | Managed by | Auto-starts | Auto-restarts |
|-----------|-----------|-------------|---------------|
| OTel Collector | launchd (`com.zdots.otel-collector`) | Yes (login) | Yes (`KeepAlive`) |
| Colima + Docker | brew services | Yes (login) | Yes |
| LGTM container | Docker (`restart: unless-stopped`) | With Docker | Yes |

### Manual Controls

```bash
# Collector
launchctl stop com.zdots.otel-collector    # stop
launchctl start com.zdots.otel-collector   # start
tail -f ~/.local/state/zsh/otel-collector.log  # logs

# LGTM stack
local-ci otel down    # stop
local-ci otel up      # start
local-ci otel logs    # logs
```
