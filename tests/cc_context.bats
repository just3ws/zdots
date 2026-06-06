#!/usr/bin/env bats
# tests/cc_context.bats — home/work context resolution + work-mode CC guard.

setup() {
  load "setup.bash"
  setup_environment
  GUARD="$REPO_ROOT/bin/cc-hook-guard"
  CTX="$REPO_ROOT/lib/cc-context.bash"
}

@test "cc_context defaults to home" {
  run env -u ZDOTS_CONTEXT ZDOTDIR="$BATS_TEST_TMPDIR" bash -c "source '$CTX'; cc_context"
  [ "$status" -eq 0 ]
  [ "$output" = "home" ]
}

@test "cc_context honours exported ZDOTS_CONTEXT" {
  run env ZDOTS_CONTEXT=work ZDOTDIR="$BATS_TEST_TMPDIR" bash -c "source '$CTX'; cc_context"
  [ "$output" = "work" ]
}

@test "cc_context reads ZDOTS_CONTEXT from .zdots.local" {
  printf 'export ZDOTS_CONTEXT=work\n' > "$BATS_TEST_TMPDIR/.zdots.local"
  run env -u ZDOTS_CONTEXT ZDOTDIR="$BATS_TEST_TMPDIR" bash -c "source '$CTX'; cc_context"
  [ "$output" = "work" ]
}

@test "guard blocks git commit on a work machine" {
  run bash -c "ZDOTS_CONTEXT=work ZDOTDIR='$REPO_ROOT' '$GUARD' <<< '{\"tool_input\":{\"command\":\"git commit -m x\"}}'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"work machine"* ]]
}

@test "guard blocks git push on a work machine" {
  run bash -c "ZDOTS_CONTEXT=work ZDOTDIR='$REPO_ROOT' '$GUARD' <<< '{\"tool_input\":{\"command\":\"git push origin main\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard allows git commit on a home machine" {
  run bash -c "ZDOTS_CONTEXT=home ZDOTDIR='$REPO_ROOT' '$GUARD' <<< '{\"tool_input\":{\"command\":\"git commit -m x\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard allows read-only git on a work machine" {
  run bash -c "ZDOTS_CONTEXT=work ZDOTDIR='$REPO_ROOT' '$GUARD' <<< '{\"tool_input\":{\"command\":\"git status\"}}'"
  [ "$status" -eq 0 ]
}
