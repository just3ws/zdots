#!/usr/bin/env bats
# tests/env_posix.bats — Verify POSIX compliance of env.sh

setup() {
  load "setup.bash"
  setup_environment
}

@test "env.sh: Sets XDG base directories" {
  # Run in a clean subshell (using bash for POSIX-like check)
  run bash -c "export ZDOTDIR=$ZDOTDIR; . $ZDOTDIR/env.sh && echo \$XDG_CONFIG_HOME"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  # Get last line to avoid noise
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$HOME/.config" ]
}

@test "env.sh: Sets ZDOTDIR if not provided" {
  # We unset ZDOTDIR inside the subshell to test fallback
  run bash -c "unset ZDOTDIR; . $ZDOTDIR/env.sh && echo \$ZDOTDIR"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$HOME/.config/zsh" ]
}

@test "env.sh: Correctly handles ZDOTS_ENV_PROFILE=ci-act" {
  run bash -c "export ZDOTDIR=$ZDOTDIR; export ZDOTS_ENV_PROFILE=ci-act; . $ZDOTDIR/env.sh && echo \$HOMEBREW_PREFIX"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "" ]
}

@test "env.sh: Selects Brewfile.home by default" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-home; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; export ZDOTDIR=\"\$tmp\"; unset ZDOTS_CONTEXT HOMEBREW_BUNDLE_FILE; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-home/Brewfile.home" ]
}

@test "env.sh: Selects Brewfile.work for work context" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-work; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; cp \"\$repo/.zdots.work\" \"\$tmp/.zdots.work\"; printf 'ZDOTS_CONTEXT=work\n' > \"\$tmp/.zdots.local\"; export ZDOTDIR=\"\$tmp\"; unset HOMEBREW_BUNDLE_FILE; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-work/Brewfile.work" ]
}

@test "env.sh: Replaces stale naked Brewfile setting" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-stale; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; cp \"\$repo/.zdots.work\" \"\$tmp/.zdots.work\"; printf 'ZDOTS_CONTEXT=work\n' > \"\$tmp/.zdots.local\"; export ZDOTDIR=\"\$tmp\"; export HOMEBREW_BUNDLE_FILE=\"\$tmp/Brewfile\"; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-stale/Brewfile.work" ]
}

@test "env.sh: Replaces inherited managed home Brewfile on work context" {
  run bash -c "repo=$ZDOTDIR; tmp=\$BATS_TEST_TMPDIR/brew-managed; mkdir -p \"\$tmp\"; cp \"\$repo/.zdots.env\" \"\$tmp/.zdots.env\"; cp \"\$repo/.zdots.work\" \"\$tmp/.zdots.work\"; printf 'ZDOTS_CONTEXT=work\n' > \"\$tmp/.zdots.local\"; export ZDOTDIR=\"\$tmp\"; export HOMEBREW_BUNDLE_FILE=\"\$tmp/Brewfile.home\"; . \"\$repo/env.sh\" && echo \$HOMEBREW_BUNDLE_FILE"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [ "$val" == "$BATS_TEST_TMPDIR/brew-managed/Brewfile.work" ]
}

@test "env.sh: Generates a 32-hex W3C Trace ID" {
  run bash -c "export ZDOTDIR=$ZDOTDIR; . $ZDOTDIR/env.sh && echo \$ZDOTS_TRACE_ID"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [[ "$val" =~ ^[0-9a-f]{32}$ ]]
}

@test "env.sh: Generates a 16-hex W3C Span ID" {
  run bash -c "export ZDOTDIR=$ZDOTDIR; . $ZDOTDIR/env.sh && echo \$ZDOTS_SPAN_ID"
  echo "Output: $output"
  [ "$status" -eq 0 ]
  local val=$(echo "$output" | tail -n 1)
  [[ "$val" =~ ^[0-9a-f]{16}$ ]]
}
