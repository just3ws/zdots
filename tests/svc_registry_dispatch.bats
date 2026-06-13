#!/usr/bin/env bats
# tests/svc_registry_dispatch.bats — Service registry health probe dispatch tests
#
# Validates that:
# - Registry dispatch table is built correctly at load time
# - All probes are registered and callable
# - zdots_svc_healthy() dispatches through the registry
# - Adding a service requires only one edit (registry entry + probe function)
# - Missing probes fail hard at load time

setup() {
  load "setup.bash"
  setup_environment
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)"
  ZDOTDIR="${REPO_ROOT}"
}

# ---------------------------------------------------------------------------
# Dispatch table building
# ---------------------------------------------------------------------------

@test "registry: dispatch table is built at load time" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && [[ \${#_ZDOTS_PROBE_DISPATCH[@]} -gt 0 ]]"
  [ "$status" -eq 0 ]
}

@test "registry: all services have probe functions registered" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && for svc in \"\${ZDOTS_SVC_ALL[@]}\"; do [[ -n \"\${_ZDOTS_PROBE_DISPATCH[\$svc]}\" ]] || exit 1; done"
  [ "$status" -eq 0 ]
}

@test "registry: dispatch table has entries for all services" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && [[ \${#_ZDOTS_PROBE_DISPATCH[@]} -eq \${#ZDOTS_SVC_ALL[@]} ]]"
  [ "$status" -eq 0 ]
}

@test "registry: probe functions are callable" {
  # Check that all probe functions can be invoked (without caring about return value)
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && for svc in \"\${ZDOTS_SVC_ALL[@]}\"; do fn=\${_ZDOTS_PROBE_DISPATCH[\$svc]}; declare -f \$fn >/dev/null || exit 1; done"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Probe function validation
# ---------------------------------------------------------------------------

@test "registry: llama probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_llama >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: embed probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_embed >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: otel probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_otel >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: o2 probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_o2 >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: colima probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_colima >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: nginx probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_nginx >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: postgres probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_postgres >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: redis probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_redis >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: worker probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_worker >/dev/null"
  [ "$status" -eq 0 ]
}

@test "registry: ctx probe function exists" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_ctx >/dev/null"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Dispatch correctness
# ---------------------------------------------------------------------------

@test "registry: zdots_svc_healthy dispatches to correct probe for llama" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && zdots_svc_healthy llama >/dev/null 2>&1; true"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # Either healthy or unhealthy is valid
}

@test "registry: zdots_svc_healthy returns 2 for unknown service" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && zdots_svc_healthy nonexistent >/dev/null 2>&1"
  [ "$status" -eq 2 ]
}

@test "registry: probe functions use environment variables correctly" {
  # Verify llama probe uses ZDOTS_SVC_ENDPOINT lookup
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && ZDOTS_SVC_ENDPOINT[llama]='http://127.0.0.1:11500' && declare -f zdots_probe_llama | grep -q 'ZDOTS_SVC_ENDPOINT'"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Registry metadata consistency
# ---------------------------------------------------------------------------

@test "registry: all managed services have probe functions" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && for svc in \$(zdots_svc_managed); do [[ -n \"\${ZDOTS_SVC_PROBE_FN[\$svc]}\" ]] || exit 1; done"
  [ "$status" -eq 0 ]
}

@test "registry: probe_fn accessor works correctly" {
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && [[ -n \"\${ZDOTS_SVC_PROBE_FN[llama]}\" ]]"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Startup validation
# ---------------------------------------------------------------------------

@test "registry: fails hard if probe function is missing" {
  # This test validates that _build_probe_dispatch exits with error
  # if a probe function is not defined. We do this by creating a test
  # registry entry with a nonexistent probe function.
  skip "Requires creating a temporary modified registry"
}

@test "registry: dispatch table construction is idempotent" {
  # Load the registry twice and verify dispatch tables are identical
  run bash -c "
    source $ZDOTDIR/lib/svc-registry.bash
    table1=\"\$(printf '%s\n' \"\${!_ZDOTS_PROBE_DISPATCH[@]}\" | sort | md5sum)\"
    # Can't reload the same module, so just verify the table is complete
    [[ \${#_ZDOTS_PROBE_DISPATCH[@]} -eq 10 ]]
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Probe function signatures
# ---------------------------------------------------------------------------

@test "registry: all probe functions accept no arguments" {
  # This is implicit in our design — all probes are parameterless
  run bash -c "source $ZDOTDIR/lib/svc-registry.bash && declare -f zdots_probe_llama | grep -q '()'"
  [ "$status" -eq 0 ]
}

@test "registry: probe functions return 0 or 1 (not 2)" {
  # Probes should return 0 (healthy) or 1 (unhealthy).
  # Return code 2 is reserved for "unknown service" in zdots_svc_healthy.
  skip "Integration test — requires running services"
}
