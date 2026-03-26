#!/usr/bin/env bats
# tests/env_posix.bats — Verify POSIX compliance of env.sh

setup() {
  load "setup.bash"
  setup_environment
}

@test "env.sh: Sets XDG base directories" {
  # Run in a clean subshell (using bash for POSIX-like check)
  run bash -c ". $ZDOTDIR/env.sh && echo \$XDG_CONFIG_HOME"
  [ "$status" -eq 0 ]
  [ "$output" == "$HOME/.config" ]
}

@test "env.sh: Sets ZDOTDIR if not provided" {
  run bash -c "unset ZDOTDIR; . $ZDOTDIR/env.sh && echo \$ZDOTDIR"
  [ "$status" -eq 0 ]
  [ "$output" == "$HOME/.config/zsh" ]
}

@test "env.sh: Correctly handles ZDOTS_ENV_PROFILE=ci-act" {
  export ZDOTS_ENV_PROFILE="ci-act"
  run bash -c ". $ZDOTDIR/env.sh && echo \$HOMEBREW_PREFIX"
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
}

@test "env.sh: Generates a 32-hex W3C Trace ID" {
  run bash -c ". $ZDOTDIR/env.sh && echo \$ZDOTS_TRACE_ID"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{32}$ ]]
}

@test "env.sh: Generates a 16-hex W3C Span ID" {
  run bash -c ". $ZDOTDIR/env.sh && echo \$ZDOTS_SPAN_ID"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{16}$ ]]
}
