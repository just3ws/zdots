#!/usr/bin/env bats
# tests/trace_log.bats — lib/trace_log.bash resilience (Z-323)

setup() {
  load "setup.bash"
  setup_environment
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  mkdir -p "$XDG_STATE_HOME/zsh"
  source "$REPO_ROOT/lib/trace_log.bash"
}

@test "zdots_trace_log writes a JSON line under normal conditions" {
  run zdots_trace_log "unit_test" "k=v"
  [ "$status" -eq 0 ]
  grep -q '"event":"unit_test"' "$XDG_STATE_HOME/zsh/traces.jsonl"
}

@test "zdots_trace_log returns 0 when the trace file is unwritable (Z-323)" {
  # Reproduce the EPERM append that aborted `zdots-ctl up` under set -e.
  local tf="$XDG_STATE_HOME/zsh/traces.jsonl"
  : > "$tf"
  chmod 0400 "$tf"
  run zdots_trace_log "platform_up" "start"
  chmod 0600 "$tf"
  [ "$status" -eq 0 ]
}

@test "a failed trace append does not abort a caller running set -e" {
  local tf="$XDG_STATE_HOME/zsh/traces.jsonl"
  : > "$tf"
  chmod 0400 "$tf"
  run bash -c 'set -euo pipefail
    source "'"$REPO_ROOT"'/lib/trace_log.bash"
    zdots_trace_log "platform_up" "start"
    echo REACHED'
  chmod 0600 "$tf"
  [ "$status" -eq 0 ]
  [[ "$output" == *REACHED* ]]
}
