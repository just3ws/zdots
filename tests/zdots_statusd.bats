#!/usr/bin/env bats
# tests/zdots_statusd.bats — contract tests for the zdots.localhost status service.
#
# zdots-statusd (the server) + zdots-statusd-ctl (the launchd manager) back the
# Observable Control Plane console at zdots.localhost. These tests assert the ctl
# grammar, the server's no-bind --help, and registry membership only — they
# never start, stop, or otherwise mutate launchd state.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
  SERVER="$BIN/zdots-statusd"
  CTL="$BIN/zdots-statusd-ctl"
}

# ── Executable + help ────────────────────────────────────────────────────────

@test "zdots-statusd: server is executable" {
  [ -x "$SERVER" ]
}

@test "zdots-statusd-ctl: ctl is executable" {
  [ -x "$CTL" ]
}

@test "zdots-statusd: --help prints usage and does NOT bind the port" {
  run "$SERVER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: zdots-statusd"* ]]
  [[ "$output" == *"/healthz"* ]]
  [[ "$output" == *"/backlog"* ]]
}

# ── Live route (only when the service is up) ────────────────────────────────

@test "zdots-statusd: /backlog renders the Backlog.md board when the service is up" {
  curl -sf --max-time 2 http://127.0.0.1:"${ZDOTS_STATUS_PORT:-11600}"/healthz >/dev/null 2>&1 \
    || skip "status service not running"
  run curl -sf --max-time 3 http://127.0.0.1:"${ZDOTS_STATUS_PORT:-11600}"/backlog
  [ "$status" -eq 0 ]
  [[ "$output" == *"the plan of record"* ]]
}

@test "zdots-statusd-ctl: --help documents the lifecycle grammar" {
  run "$CTL" --help
  [ "$status" -eq 0 ]
  for verb in install start stop restart status health logs run; do
    [[ "$output" == *"$verb"* ]]
  done
}

@test "zdots-statusd-ctl: unknown command fails with usage" {
  run "$CTL" bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command"* ]]
}

# ── Registry membership (read-only) ──────────────────────────────────────────

@test "svc-registry: 'status' resolves and is zsvc-managed" {
  run bash -c "ZDOTDIR='$REPO_ROOT' source '$REPO_ROOT/lib/svc-registry.bash' && zdots_svc_resolve status && zdots_svc_managed"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status"* ]]
}

@test "svc-registry: zdots_probe_status is defined" {
  run bash -c "ZDOTDIR='$REPO_ROOT' source '$REPO_ROOT/lib/svc-registry.bash' && declare -f zdots_probe_status >/dev/null && echo defined"
  [ "$status" -eq 0 ]
  [[ "$output" == *"defined"* ]]
}
