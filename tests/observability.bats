#!/usr/bin/env bats
# tests/observability.bats — Verify Zsh-specific observability logic

setup() {
  load "setup.bash"
  setup_environment
}

@test "Zsh: Generates ZDOTS_SESSION_ID in interactive shell" {
  # Run in interactive mode to trigger all hooks
  run zsh -i -c 'echo $ZDOTS_SESSION_ID'
  echo "Output: $output"
  [ "$status" -eq 0 ]
  # Strip ANSI/OSC escape sequences (iTerm2 shell integration injects these)
  local val
  val=$(echo "$output" | sed $'s/\x1b\][^\x07]*\x07//g; s/\x1b\\[[0-9;]*[a-zA-Z]//g' | grep -Eo '[0-9a-f]{32}' | tail -n 1)
  [[ "$val" =~ ^[0-9a-f]{32}$ ]]
}

@test "Zsh: Hooks are correctly registered in interactive shell" {
  # Verify that our observability hook is in the preexec_functions array
  run zsh -i -c 'typeset -p preexec_functions'
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"_zdots_trace_preexec"* ]]
}

@test "Zsh: Manual preexec call rotates Span ID" {
  # Since zsh -c 'cmd' runs 'cmd' as the primary command without triggering hooks for it,
  # we verify the rotation logic by calling the hook manually.
  run zsh -i -c 'id1=$ZDOTS_SPAN_ID; _zdots_trace_preexec "test"; id2=$ZDOTS_SPAN_ID; if [ "$id1" != "$id2" ]; then echo "ROTATED"; fi'
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ROTATED"* ]]
}

@test "Zsh: Injects traceparent header into curl" {
  # We test the wrapper by checking if it contains the header flag
  run zsh -i -c 'typeset -f curl'
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"traceparent: \$TRACEPARENT"* ]]
}

@test "Zsh: OTEL_SERVICE_NAME is not exported to child processes" {
  # Child processes should not inherit the shell's service name.
  # env(1) runs as a child process and prints its environment.
  # Use env -i to start from a clean environment so we test only what zdots sets,
  # not what the parent shell already exported.
  run env -i HOME="$HOME" ZDOTDIR="$ZDOTDIR" TERM=xterm-256color \
    zsh -i -c 'env | grep "^OTEL_SERVICE_NAME=" || echo "NOT_EXPORTED"'
  echo "Output: $output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT_EXPORTED"* ]]
}
