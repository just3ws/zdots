#!/usr/bin/env bats
# tests/observability.bats — Verify Zsh-specific observability logic

setup() {
  load "setup.bash"
  setup_environment
}

@test "Zsh: Generates ZDOTS_SESSION_ID in interactive shell" {
  # Run in interactive mode to trigger all hooks
  run zsh -i -c "echo \$ZDOTS_SESSION_ID"
  assert_success
  assert_output --regexp '^[0-9a-f]{32}$'
}

@test "Zsh: Hooks are correctly registered in interactive shell" {
  # Verify that our observability hook is in the preexec_functions array
  run zsh -i -c 'typeset -p preexec_functions'
  assert_success
  assert_output --partial "_zdots_trace_preexec"
}

@test "Zsh: Manual preexec call rotates Span ID" {
  # Since zsh -c 'cmd' runs 'cmd' as the primary command without triggering hooks for it,
  # we verify the rotation logic by calling the hook manually.
  run zsh -i -c 'id1=$ZDOTS_SPAN_ID; _zdots_trace_preexec "test"; id2=$ZDOTS_SPAN_ID; if [ "$id1" != "$id2" ]; then echo "ROTATED"; fi'
  assert_success
  assert_output --partial "ROTATED"
}

@test "Zsh: Injects traceparent header into curl" {
  # We test the wrapper by checking if it contains the header flag
  run zsh -i -c "typeset -f curl"
  assert_success
  assert_output --partial "traceparent: \$TRACEPARENT"
}
