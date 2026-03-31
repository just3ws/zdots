# Connecting to the Local OTel Collector

This machine runs a bare-metal OpenTelemetry Collector (`otelcol-contrib`) that accepts telemetry from any local application and forwards it to a central LGTM (Loki, Grafana, Tempo, Mimir) stack.

## Endpoint

```
http://127.0.0.1:4318
```

This is an **OTLP/HTTP** endpoint. All three signal types are accepted:

| Signal  | URL                              |
|---------|----------------------------------|
| Traces  | `http://127.0.0.1:4318/v1/traces`  |
| Metrics | `http://127.0.0.1:4318/v1/metrics` |
| Logs    | `http://127.0.0.1:4318/v1/logs`    |

**Important:** Always use `127.0.0.1`, not `localhost`. gRPC clients resolve `localhost` to IPv6 (`[::1]`) first, which fails on this setup.

## How to Configure Your Application

### Environment Variables (OTEL SDK Standard)

Most OpenTelemetry SDKs respect these environment variables:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_SERVICE_NAME="your-service-name"
```

Set `OTEL_SERVICE_NAME` to your application's identity (e.g., `phalanx-server`, `my-api`). Each service must set its own name — the shell does NOT export a default.

### Language Examples

**Node.js / TypeScript** (with `@opentelemetry/sdk-node`):
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318 \
OTEL_SERVICE_NAME=my-node-app \
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

**Python** (with `opentelemetry-distro`):
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318 \
OTEL_SERVICE_NAME=my-python-app \
opentelemetry-instrument python app.py
```

**Go** (with `go.opentelemetry.io/otel`):
```go
exporter, _ := otlptracehttp.New(ctx,
    otlptracehttp.WithEndpoint("127.0.0.1:4318"),
    otlptracehttp.WithInsecure(),
)
```

**Rust** (with `opentelemetry-otlp`):
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318 \
OTEL_SERVICE_NAME=my-rust-app \
cargo run
```

**curl** (manual test):
```bash
curl -X POST http://127.0.0.1:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test"}}]},"scopeSpans":[{"spans":[{"traceId":"abcdef1234567890abcdef1234567890","spanId":"1234567890abcdef","name":"test.span","startTimeUnixNano":"1700000000000000000","endTimeUnixNano":"1700000001000000000"}]}]}]}'
```

## What Happens to Your Telemetry

The collector routes data through three exporters:

1. **Debug** — printed to the collector log (`~/.local/state/zsh/otel-collector.log`)
2. **File** — written to `~/.local/state/zsh/collector-traces.json` (10MB rotation, 3 backups)
3. **LGTM** — forwarded via gRPC to the Grafana stack at `127.0.0.1:4417`

## Viewing Your Data

- **Grafana:** http://127.0.0.1:3000 (default credentials: `admin` / `admin`)
  - **Traces:** Explore → Tempo datasource → Search by service name or trace ID
  - **Logs:** Explore → Loki datasource
  - **Metrics:** Explore → Prometheus datasource

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
