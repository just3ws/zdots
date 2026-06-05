#!/usr/bin/env bats
# tests/zdots_worker.bats — contract tests for the worker Platform Service.
#
# The worker (bin/zdots-worker) drains the async job queue for the `my`
# database. These tests assert the ctl grammar and read-only behaviour only;
# they never start, stop, or otherwise mutate launchd state.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
  WORKER="$BIN/zdots-worker"
}

# ---------------------------------------------------------------------------
# Stateless contract — no live service required
# ---------------------------------------------------------------------------

@test "zdots-worker: is executable" {
  [ -x "$WORKER" ]
}

@test "zdots-worker: --help documents the lifecycle grammar" {
  run "$WORKER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  for verb in install start stop restart status health logs run; do
    [[ "$output" == *"$verb"* ]]
  done
}

@test "zdots-worker: unknown command exits non-zero" {
  run "$WORKER" frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command"* ]]
}

@test "zdots-worker: no command prints usage and fails" {
  run "$WORKER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "zdots-worker: status is read-only and never crashes" {
  run "$WORKER" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"jobs queue"* ]]
}

@test "zdots-worker: status --json emits parseable JSON" {
  run "$WORKER" status --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
}

@test "zdots-worker: the run entry point keeps the secret out of the plist" {
  # ZDOTS_DB_ENCRYPTION_KEY must be loaded at runtime, never embedded.
  run grep -n "ZDOTS_SVC_ENV_KEYS" "$WORKER"
  [ "$status" -eq 0 ]
  # The only env keys placed in the plist are HOME, PATH, ZDOTDIR — not the key.
  [[ "$output" == *'HOME PATH ZDOTDIR'* ]]
  ! grep -q 'ZDOTS_SVC_ENV_KEYS=.*ZDOTS_DB_ENCRYPTION_KEY' "$WORKER"
}

# ---------------------------------------------------------------------------
# Live — only when the launchd agent is registered
# ---------------------------------------------------------------------------

@test "zdots-worker: registered agent reports running and healthy" {
  local label="com.zdots.worker"
  if ! launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1; then
    skip "worker launchd agent not registered (run: zsvc start worker)"
  fi
  run "$WORKER" health
  [ "$status" -eq 0 ]
}

@test "zdots-worker: appears in zsvc list when registered" {
  local label="com.zdots.worker"
  if ! launchctl print "gui/$(id -u)/${label}" >/dev/null 2>&1; then
    skip "worker launchd agent not registered"
  fi
  run "$BIN/zsvc" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"zdots-worker"* ]]
}
