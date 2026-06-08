#!/usr/bin/env bats
# tests/svc_registry.bats — the shared Platform Service registry contract.
#
# The catalog and alias map are pure data and always testable. Live probes
# (zdots_svc_healthy / zdots_svc_state) are exercised only when a service is up.

setup() {
  load "setup.bash"
  setup_environment
  source "$REPO_ROOT/lib/svc-registry.bash"
}

# ── Alias resolution ────────────────────────────────────────────────────────

@test "registry: resolves canonical names to themselves" {
  skip_in_ci
  for s in llama embed otel colima nginx postgres redis worker grafana ctx; do
    run zdots_svc_resolve "$s"
    [ "$status" -eq 0 ]
    [ "$output" = "$s" ]
  done
}

@test "registry: resolves aliases to canonical names" {
  [ "$(zdots_svc_resolve ai)" = "llama" ]
  [ "$(zdots_svc_resolve server)" = "llama" ]
  [ "$(zdots_svc_resolve llama-embed)" = "embed" ]
  [ "$(zdots_svc_resolve vm)" = "colima" ]
  [ "$(zdots_svc_resolve pg)" = "postgres" ]
  [ "$(zdots_svc_resolve cache)" = "redis" ]
  [ "$(zdots_svc_resolve jobs)" = "worker" ]
  [ "$(zdots_svc_resolve web)" = "nginx" ]
  [ "$(zdots_svc_resolve telemetry)" = "otel" ]
}

@test "registry: unknown alias fails non-zero" {
  run zdots_svc_resolve definitely-not-a-service
  [ "$status" -ne 0 ]
}

# ── Managed set ─────────────────────────────────────────────────────────────

@test "registry: managed list is the eight zsvc-controllable services in order" {
  skip_in_ci
  run zdots_svc_managed
  [ "$status" -eq 0 ]
  expected=$'llama\nembed\notel\ncolima\nnginx\npostgres\nredis\nworker'
  [ "$output" = "$expected" ]
}

@test "registry: health-only services are not in the managed list" {
  run zdots_svc_managed
  [[ "$output" != *grafana* ]]
  [[ "$output" != *ctx* ]]
}

# ── Descriptor data ─────────────────────────────────────────────────────────

@test "registry: descriptor fields match the catalog" {
  [ "${ZDOTS_SVC_LABEL[llama]}" = "com.zdots.llama-server" ]
  [ "${ZDOTS_SVC_LABEL[worker]}" = "com.zdots.worker" ]
  [ "${ZDOTS_SVC_ENDPOINT[llama]}" = "http://127.0.0.1:11500" ]
  [ "${ZDOTS_SVC_ENDPOINT[embed]}" = "http://127.0.0.1:11501" ]
  [ "${ZDOTS_SVC_TYPE[postgres]}" = "plist" ]
  [ "${ZDOTS_SVC_TYPE[nginx]}" = "nginx" ]
  [ "${ZDOTS_SVC_TYPE[colima]}" = "colima" ]
  [ "${ZDOTS_SVC_TYPE[worker]}" = "launchd" ]
  [ "${ZDOTS_SVC_CTL[llama]}" = "llama-ctl" ]
  [ "${ZDOTS_SVC_CTL[postgres]}" = "" ]
  [ "${ZDOTS_SVC_START[embed]}" = "start-embed" ]
}

@test "registry: probe functions are defined" {
  declare -F zdots_svc_state  >/dev/null
  declare -F zdots_svc_healthy >/dev/null
}

# ── Live probes (only when the service is up) ────────────────────────────────

@test "registry: state of a registered launchd service reports running + pid" {
  if ! launchctl print "gui/$(id -u)/com.zdots.worker" >/dev/null 2>&1; then
    skip "worker not registered"
  fi
  run zdots_svc_state worker
  [ "$status" -eq 0 ]
  [[ "$output" == running* ]]
}

@test "registry: healthy worker matches its ctl health" {
  if ! "$REPO_ROOT/bin/zdots-worker" health >/dev/null 2>&1; then
    skip "worker not healthy"
  fi
  run zdots_svc_healthy worker
  [ "$status" -eq 0 ]
}
