# OTel Stack Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix shell telemetry pipeline so traces flow end-to-end from zdots shell through the OTel collector to a freshly rebuilt LGTM stack in Grafana/Tempo.

**Architecture:** Three-layer fix: (1) stop `OTEL_SERVICE_NAME` from leaking to child processes, (2) harden the collector config with absolute paths and rotation, (3) rebuild LGTM from v0.8.1 to v0.22.1. Validate with Bats tests and a live end-to-end trace check.

**Tech Stack:** Zsh, OpenTelemetry Collector (otelcol-contrib), Docker Compose, Grafana LGTM stack, Bats (testing)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `env.sh` | Modify (lines 128-129) | Remove `export` from OTEL env vars |
| `providers/trace/otlp.zsh` | Modify (lines 11, 80) | Remove `export` from `OTEL_SERVICE_NAME`; fix background job noise (`&` → `&!`) |
| `conf.d/05-observability.zsh` | Modify (lines 24-29, 72-78) | Pass service name inline to otel-cli calls |
| `etc/otel-collector.yaml` | Modify (lines 19-20) | Absolute path + rotation for file exporter |
| `etc/docker-compose.lgtm.yaml` | Modify (line 7) | Bump image tag to v0.22.1 |
| `tests/observability.bats` | Modify (add test) | Service name isolation test |

---

### Task 1: Fix OTEL_SERVICE_NAME Scope Pollution

Child processes (like `phalanx-server`) inherit `OTEL_SERVICE_NAME=zdots-shell` because it's exported in two places. This causes all their traces to be misattributed as `zdots-shell` in Grafana. The fix: stop exporting the variable so it's only visible within the shell process, and pass it explicitly to otel-cli (which runs as a child process and needs it).

**Files:**
- Modify: `env.sh:129`
- Modify: `providers/trace/otlp.zsh:11`
- Modify: `conf.d/05-observability.zsh:22-29,66-78`
- Test: `tests/observability.bats`

- [ ] **Step 1: Write the failing test for service name isolation**

Add a new test to `tests/observability.bats` that verifies `OTEL_SERVICE_NAME` is NOT exported to child processes:

```bash
@test "Zsh: OTEL_SERVICE_NAME is not exported to child processes" {
  # Child processes should not inherit the shell's service name.
  # env(1) runs as a child process and prints its environment.
  run zsh -i -c 'env | grep "^OTEL_SERVICE_NAME=" || echo "NOT_EXPORTED"'
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT_EXPORTED"* ]]
}
```

Append this test at the end of `tests/observability.bats`, before the final newline.

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/observability.bats --filter "OTEL_SERVICE_NAME"`
Expected: FAIL — currently the variable IS exported.

- [ ] **Step 3: Remove export from env.sh**

In `env.sh`, change line 129 from:

```sh
export OTEL_SERVICE_NAME="zdots-shell"
```

to:

```sh
OTEL_SERVICE_NAME="zdots-shell"
```

This keeps the variable available in the current shell (for `zdots_trace_init()` to read) but prevents child processes from inheriting it.

- [ ] **Step 4: Remove export from otlp.zsh**

In `providers/trace/otlp.zsh`, change line 11 from:

```zsh
export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-zdots-shell}"
```

to:

```zsh
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-zdots-shell}"
```

- [ ] **Step 5: Pass service name inline to otel-cli in error span**

In `conf.d/05-observability.zsh`, the error span (lines 22-31) uses otel-cli as a child process. Since `OTEL_SERVICE_NAME` is no longer exported, pass it inline. Change:

```zsh
      if command -v otel-cli >/dev/null 2>&1; then
        (
          otel-cli span \
            --name "command.error" \
            --attrs "status=$last_status,command=$ZDOTS_LAST_COMMAND" \
            --force-trace-id "$ZDOTS_TRACE_ID" \
            --force-span-id "$ZDOTS_SPAN_ID" \
            --status "error" \
            >/dev/null 2>&1
        ) &!
      fi
```

to:

```zsh
      if command -v otel-cli >/dev/null 2>&1; then
        (
          OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME" \
          OTEL_EXPORTER_OTLP_ENDPOINT="$OTEL_EXPORTER_OTLP_ENDPOINT" \
          otel-cli span \
            --name "command.error" \
            --attrs "status=$last_status,command=$ZDOTS_LAST_COMMAND" \
            --force-trace-id "$ZDOTS_TRACE_ID" \
            --force-span-id "$ZDOTS_SPAN_ID" \
            --status "error" \
            >/dev/null 2>&1
        ) &!
      fi
```

- [ ] **Step 6: Pass service name inline to otel-cli in heartbeat span**

In `conf.d/05-observability.zsh`, the heartbeat span (lines 66-78) also uses otel-cli. Change:

```zsh
  if command -v otel-cli >/dev/null 2>&1; then
    # Capture system health (Load Average)
    local load_avg=$(uptime | awk -F'load averages: ' '{ print $2 }' | awk '{ print $1 }' || echo "unknown")

    # Send a backgrounded heartbeat span
    (
      otel-cli span \
        --name "shell.heartbeat" \
        --attrs "profile=${ZDOTS_ENV_PROFILE:-unknown},os=$(uname -s),sys.load_avg=$load_avg" \
        --force-trace-id "$ZDOTS_TRACE_ID" \
        --force-span-id "$ZDOTS_SPAN_ID" \
        >/dev/null 2>&1
    ) &!
  fi
```

to:

```zsh
  if command -v otel-cli >/dev/null 2>&1; then
    # Capture system health (Load Average)
    local load_avg=$(uptime | awk -F'load averages: ' '{ print $2 }' | awk '{ print $1 }' || echo "unknown")

    # Send a backgrounded heartbeat span
    (
      OTEL_SERVICE_NAME="$OTEL_SERVICE_NAME" \
      OTEL_EXPORTER_OTLP_ENDPOINT="$OTEL_EXPORTER_OTLP_ENDPOINT" \
      otel-cli span \
        --name "shell.heartbeat" \
        --attrs "profile=${ZDOTS_ENV_PROFILE:-unknown},os=$(uname -s),sys.load_avg=$load_avg" \
        --force-trace-id "$ZDOTS_TRACE_ID" \
        --force-span-id "$ZDOTS_SPAN_ID" \
        >/dev/null 2>&1
    ) &!
  fi
```

The `VAR=value command` syntax sets the variable ONLY for that child process invocation.

- [ ] **Step 7: Also stop exporting OTEL_EXPORTER_OTLP_ENDPOINT**

In `env.sh`, change line 128 from:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
```

to:

```sh
OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
```

This prevents child processes from blindly sending telemetry to the shell's collector. Services that need a collector should configure their own endpoint. The inline `OTEL_EXPORTER_OTLP_ENDPOINT=...` in Step 5 and Step 6 handles the otel-cli cases.

- [ ] **Step 8: Fix background curl job noise in OTLP trace sender**

In `providers/trace/otlp.zsh`, the `_zdots_trace_send_otlp` function backgrounds curl with `&` (line 80), which leaves it in zsh's job table. When the curl completes, zsh prints `[N] done command curl ...` after every command. Fix by using `&!` (background + disown) to suppress job completion messages.

In `providers/trace/otlp.zsh`, change line 80 from:

```zsh
    -d "$payload" "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/traces" >/dev/null 2>&1 &
```

to:

```zsh
    -d "$payload" "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/traces" >/dev/null 2>&1 &!
```

The `&!` is zsh syntax for `& disown` — it backgrounds the process AND removes it from the job table, preventing the shell from printing completion messages.

- [ ] **Step 9: Run tests to verify the fix**

Run: `bats tests/observability.bats`
Expected: ALL tests pass, including the new isolation test.

- [ ] **Step 10: Run full regression suite**

Run: `make check`
Expected: All checks pass. The removal of `export` should not affect any shell-internal functionality since the variable remains set in the shell process.

- [ ] **Step 11: Commit**

```bash
git add env.sh providers/trace/otlp.zsh conf.d/05-observability.zsh tests/observability.bats
git commit -m "fix: scope OTEL env vars and silence background job noise

OTEL_SERVICE_NAME and OTEL_EXPORTER_OTLP_ENDPOINT were exported globally,
causing child processes (e.g. phalanx-server) to inherit zdots-shell as
their service name. Now kept as shell-local variables with inline passing
to otel-cli invocations. Also fixed background curl using & instead of &!
which caused job completion noise on every traced command."
```

---

### Task 2: Harden OTel Collector Configuration

The collector file exporter uses a relative path (`./traces-collected.json`) which depends on the collector's working directory, and has no rotation — the file grows without bounds. Fix both.

**Files:**
- Modify: `etc/otel-collector.yaml:14-25`

- [ ] **Step 1: Update the file exporter config**

In `etc/otel-collector.yaml`, replace the file exporter section:

```yaml
  # Local Storage: Save to local JSON file
  file:
    path: "./traces-collected.json"
```

with:

```yaml
  # Local Storage: Save to XDG-compliant location with rotation
  file:
    path: "${env:HOME}/.local/state/zsh/collector-traces.json"
    rotation:
      max_megabytes: 10
      max_backups: 3
```

This uses the `${env:HOME}` syntax supported by the OTel collector for environment variable expansion. The file lands next to the shell's own `traces.jsonl` in the XDG state directory. Rotation keeps at most 3 old files of 10MB each.

- [ ] **Step 2: Verify collector config is valid**

Run: `otelcol-contrib validate --config /Users/mike/.config/zsh/etc/otel-collector.yaml 2>&1`
Expected: No errors. If the `validate` subcommand isn't available, this will be tested when the collector restarts in Task 4.

- [ ] **Step 3: Commit**

```bash
git add etc/otel-collector.yaml
git commit -m "fix: use absolute path and rotation for collector file exporter

Relative path was fragile (depended on CWD). Now writes to
~/.local/state/zsh/collector-traces.json with 10MB rotation and 3 backups."
```

---

### Task 3: Rebuild LGTM Stack to Latest Version

The LGTM stack is running v0.8.1 (Grafana 11.4, Tempo 2.6.1). Latest is v0.22.1 (Grafana 12.4.1, Tempo 2.10.3). Update the compose file and rebuild the container fresh.

**Files:**
- Modify: `etc/docker-compose.lgtm.yaml:7`

- [ ] **Step 1: Update the image tag in docker-compose**

In `etc/docker-compose.lgtm.yaml`, change line 7 from:

```yaml
    image: grafana/otel-lgtm:0.8.1
```

to:

```yaml
    image: grafana/otel-lgtm:0.22.1
```

- [ ] **Step 2: Stop and remove the old container and volume**

```bash
cd /Users/mike/.config/zsh
docker compose -f etc/docker-compose.lgtm.yaml down -v
```

The `-v` flag removes the named volume `lgtm-data`, ensuring a clean slate with no stale data from the old version.

- [ ] **Step 3: Pull the new image (already pulled, but ensure it's current)**

```bash
docker pull grafana/otel-lgtm:0.22.1
```

Expected: Image layers already present or freshly downloaded.

- [ ] **Step 4: Start the new LGTM stack**

```bash
cd /Users/mike/.config/zsh
docker compose -f etc/docker-compose.lgtm.yaml up -d
```

Expected: Container `zdots-lgtm` starts with the new image.

- [ ] **Step 5: Verify the new stack is healthy**

```bash
# Wait for Grafana to be ready (may take 10-15 seconds on first start)
sleep 10
curl -s http://localhost:3000/api/health | jq .
```

Expected: `{"commit":"...","database":"ok","version":"12.4.1"}`

```bash
# Verify Tempo is accepting traces
curl -s -o /dev/null -w "%{http_code}" http://localhost:4418/v1/traces
```

Expected: `405` (wants POST, not GET — confirms the endpoint is listening)

```bash
# Verify Loki is accessible
curl -s http://localhost:3100/ready
```

Expected: `ready`

- [ ] **Step 6: Clean up old image (optional)**

```bash
docker rmi grafana/otel-lgtm:0.8.1
```

Expected: Image removed. Skip if other containers depend on it.

- [ ] **Step 7: Commit**

```bash
git add etc/docker-compose.lgtm.yaml
git commit -m "chore: upgrade LGTM stack from v0.8.1 to v0.22.1

Major version bump: Grafana 11.4→12.4.1, Tempo 2.6.1→2.10.3,
Loki 3.3.1→3.6.7, OTel Collector 0.115→0.147, Prometheus 3.0→3.10.
Clean rebuild with fresh volume."
```

---

### Task 4: Restart Collector and Validate End-to-End Pipeline

With the config changes from Tasks 1-3, restart the bare-metal collector and verify traces flow from shell through the collector into Grafana/Tempo.

**Files:**
- None (operational task)

- [ ] **Step 1: Stop the old collector process**

```bash
pkill -f "otelcol-contrib.*otel-collector.yaml" || true
```

Verify it stopped:
```bash
pgrep -fl otelcol
```

Expected: No output (process gone).

- [ ] **Step 2: Start the collector with the updated config**

```bash
otelcol-contrib --config /Users/mike/.config/zsh/etc/otel-collector.yaml > /tmp/otelcol.log 2>&1 &
disown
```

Verify it started:
```bash
sleep 2
pgrep -fl otelcol
```

Expected: Process running with the config path.

- [ ] **Step 3: Verify collector can reach LGTM**

```bash
tail -20 /tmp/otelcol.log 2>/dev/null
```

Expected: No connection errors. Should show the exporter starting successfully.

- [ ] **Step 4: Send a test trace and verify it reaches the collector**

```bash
# Send a manual test span via curl to the collector
curl -s -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"zdots-test"}}]},"scopeSpans":[{"spans":[{"traceId":"abcdef1234567890abcdef1234567890","spanId":"1234567890abcdef","name":"test.validation","startTimeUnixNano":"'$(date +%s)'000000000","endTimeUnixNano":"'$(date +%s)'000000000"}]}]}]}'
```

Expected: HTTP 200 OK.

Verify it landed in the collector file:
```bash
grep "test.validation" ~/.local/state/zsh/collector-traces.json
```

Expected: The test span appears in the file.

- [ ] **Step 5: Verify trace reaches Tempo via Grafana API**

```bash
# Query Tempo for the test trace (may take a few seconds for the batch processor to flush)
sleep 5
curl -s "http://localhost:3000/api/datasources/proxy/uid/tempo/api/traces/abcdef1234567890abcdef1234567890" 2>/dev/null | jq '.batches[0].scopeSpans[0].spans[0].name' 2>/dev/null
```

Expected: `"test.validation"` — confirms the trace flowed through the full pipeline: curl → collector → LGTM → Tempo → Grafana.

If the datasource UID differs, find it first:
```bash
curl -s http://localhost:3000/api/datasources | jq '.[] | select(.type=="tempo") | .uid'
```

- [ ] **Step 6: Open an interactive shell and verify zdots traces generate**

```bash
# Start a new interactive shell and run a command to generate traces
zsh -i -c 'echo "trace test"; sleep 1; exit'
```

Then check the local trace file for the session:
```bash
tail -5 ~/.local/state/zsh/traces.jsonl
```

Expected: Recent `session_start` and `exec` events with fresh timestamps.

- [ ] **Step 7: Run full regression suite one final time**

Run: `make check`
Expected: All checks pass.

---

## Verification Summary

After all tasks, these should be true:

1. `env | grep OTEL_SERVICE_NAME` in an interactive shell returns nothing (not exported)
2. `echo $OTEL_SERVICE_NAME` in an interactive shell returns `zdots-shell` (set locally)
3. LGTM container runs `grafana/otel-lgtm:0.22.1` with healthy Grafana, Tempo, and Loki
4. Collector writes to `~/.local/state/zsh/collector-traces.json` (absolute, with rotation)
5. Test traces sent to the collector appear in Grafana/Tempo
6. `make check` passes (including new service name isolation test)
7. `bats tests/observability.bats` passes all 5 tests
