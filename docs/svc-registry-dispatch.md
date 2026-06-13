# Service Registry Dispatch Architecture

## Overview

The Service Registry consolidates health probe logic into a centralized dispatch mechanism. Previously, health probes were scattered across multiple scripts (lib/svc-health.bash, bin/zsvc, bin/zdots-ctl) as convention-based case statements. Adding a service required edits in 3+ places; misnamed probe functions failed silently.

**New design:** Registry metadata includes a probe function reference. At load time, the registry builds a dispatch table (`_ZDOTS_PROBE_DISPATCH`) that maps service name → probe function, validating all probes exist and failing hard if any are missing.

## Files Changed

- **lib/svc-registry.bash** — Core refactoring
  - Added `ZDOTS_SVC_PROBE_FN` array (probe function names per service)
  - Defined 10 probe functions (`zdots_probe_llama`, `zdots_probe_otel`, etc.)
  - Added `_build_probe_dispatch()` to validate and build dispatch table
  - Refactored `zdots_svc_healthy()` to dispatch through registry
  
- **tests/svc_registry_dispatch.bats** — New test suite
  - 23 tests covering dispatch table construction, probe validation, dispatch correctness
  - All tests pass

## Architecture

### Probe Function Definition

Each service has a corresponding probe function:

```bash
zdots_probe_llama() {
  curl -sf --max-time 3 "${ZDOTS_SVC_ENDPOINT[llama]}/health" >/dev/null 2>&1
}

zdots_probe_postgres() {
  command -v pg_isready >/dev/null 2>&1 && pg_isready -q 2>/dev/null
}
```

**Signature:** All probes are parameterless functions that return 0 (healthy) or 1 (unhealthy).

### Registry Catalog

Each service registration now includes a `probe_fn` field (18th field):

```bash
_svc_reg "llama|llama-server|com.zdots.llama-server|...|zdots_probe_llama"
_svc_reg "postgres|postgresql@18|...|zdots_probe_postgres"
```

### Dispatch Table Building

At registry load time, `_build_probe_dispatch()` is called:

1. Iterates over `ZDOTS_SVC_ALL[@]`
2. For each service, retrieves `ZDOTS_SVC_PROBE_FN[$svc]`
3. Verifies the probe function exists (`declare -f $probe_fn`)
4. Populates `_ZDOTS_PROBE_DISPATCH[$svc] = $probe_fn`
5. **Fails hard** (exits 1) if any probe is missing

Example dispatch table after load:

```
_ZDOTS_PROBE_DISPATCH[llama]=zdots_probe_llama
_ZDOTS_PROBE_DISPATCH[embed]=zdots_probe_embed
_ZDOTS_PROBE_DISPATCH[otel]=zdots_probe_otel
_ZDOTS_PROBE_DISPATCH[postgres]=zdots_probe_postgres
...
```

### Health Check Dispatch

`zdots_svc_healthy()` now dispatches through the registry:

```bash
zdots_svc_healthy() {
  local name; name="$(zdots_svc_resolve "$1")" || return 2
  local probe_fn="${_ZDOTS_PROBE_DISPATCH[$name]:-}"
  if [[ -z "$probe_fn" ]]; then
    return 2
  fi
  # Call the registered probe function
  "$probe_fn"
}
```

Return codes:
- **0** — Service is healthy
- **1** — Service is unhealthy
- **2** — Unknown service or probe not found

## Usage

### For Script Authors

`zsvc` and `zdots-ctl` already use `zdots_svc_healthy()`, so they automatically benefit:

```bash
# In bin/zsvc
if zdots_svc_healthy "$SVC_NAME"; then
  _ok "service is healthy"
else
  _warn "service is unhealthy"
fi

# In bin/zdots-ctl
_ai_up() { zdots_svc_healthy llama; }
_otel_up() { zdots_svc_healthy otel; }
```

### Adding a New Service

One edit (registry entry + probe function):

1. Define the probe function in lib/svc-registry.bash:

```bash
zdots_probe_myservice() {
  curl -sf --max-time 3 "${ZDOTS_SVC_ENDPOINT[myservice]}/health" >/dev/null 2>&1
}
```

2. Add the service to the catalog with probe_fn field:

```bash
_svc_reg "myservice|...|install|start|stop|restart|status|health|logs|validate|zdots_probe_myservice"
```

3. No other edits needed — dispatch table is built automatically at load time.

## Testing

Run the test suite:

```bash
bats tests/svc_registry_dispatch.bats
```

Tests verify:
- Dispatch table is built at load time
- All probes are registered and callable
- `zdots_svc_healthy()` dispatches correctly
- Unknown service returns code 2
- Registry fails hard if a probe is missing

Existing tests (cli_contracts.bats) continue to pass — no behavioral changes to zdots-ctl or zsvc.

## Validation

The registry validates probe existence at **load time** (not call time). Attempting to source the registry with a missing probe:

```bash
# This fails hard:
source lib/svc-registry.bash
# svc-registry: ERROR: probe function zdots_probe_missing for service myservice does not exist
# svc-registry: FATAL: probe dispatch table build failed
```

This prevents silent failures from typos or incomplete refactorings.

## Migration Path

This refactoring is **backward compatible**. No changes to:
- `zdots_svc_resolve()`, `zdots_svc_managed()`, `zdots_svc_state()`
- Accessor functions (`zdots_svc_display()`, `zdots_svc_label()`, etc.)
- `bin/zsvc` and `bin/zdots-ctl` behavior or output
- Any public API

The `zdots_svc_healthy()` function was already the single source of truth for health checks; this refactoring only improves its internal design.

## Benefits

1. **Single edit to add a service** — Registry entry + probe function only
2. **Fail-fast validation** — Missing probes caught at startup, not at health-check time
3. **Locality** — All service metadata (including probe) in one place
4. **Testability** — Dispatch table is introspectable and mockable
5. **Maintainability** — No service-specific case statements scattered across zdots-ctl/zsvc
6. **Explicit over implicit** — Probe functions are named, defined, and registered explicitly

## Related Documentation

- [Platform Service Plane](platform-service-plane.md) — Service topology and lifecycle
- [lib/svc-registry.bash](../lib/svc-registry.bash) — Registry implementation
- [bin/zsvc](../bin/zsvc) — Per-service control
- [bin/zdots-ctl](../bin/zdots-ctl) — Platform orchestration
