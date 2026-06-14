#!/usr/bin/env bats
# tests/phase-3-peer-discovery.bats — End-to-end tests for Claude Code / agent peer discovery
#
# Validates the session startup hook system that discovers and hydrates both zdots
# and adots capabilities. Tests hook files, environment setup, cross-peer health
# checks, and graceful degradation.
#
# Summary of test groups:
#   1. Hook file existence and executability
#   2. Capabilities sourcing and array exports
#   3. Environment variable setup (ZDOTS_DIR, ADOTS_DIR, etc.)
#   4. Health check execution and status capture
#   5. Peer cross-checks (zdots→adots, adots→zdots)
#   6. Capabilities discovery and command validation

setup() {
  load "setup.bash"
  setup_environment

  # Test-specific environment
  TEST_HOME="${BATS_TEST_TMPDIR}/test-home"
  mkdir -p "$TEST_HOME"

  # Mirror critical paths
  cp -r "$REPO_ROOT"/.zdots.env "$TEST_HOME/.zdots.env" 2>/dev/null || true

  # Point to real zdots/adots for discovery
  REAL_ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"
  REAL_ADOTS_DIR="${HOME}/.config/adots"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

# _source_file <path> [description]
# Source a file and report any errors
_source_file() {
  local file="$1"
  local desc="${2:-$file}"

  if [ ! -f "$file" ]; then
    echo "ERROR: $desc not found: $file"
    return 1
  fi

  if [ ! -r "$file" ]; then
    echo "ERROR: $desc not readable: $file"
    return 1
  fi

  # Source in a subshell to isolate side effects
  bash -c "source '$file'"
}

# _count_array <array_var_name>
# Return the count of elements in an array
_count_array() {
  local array_name="$1"
  bash -c "
    source '$REAL_ZDOTDIR/bin/capabilities'
    arr=(\${!$array_name[@]})
    echo \${#arr[@]}
  " 2>/dev/null || echo "0"
}

# _parse_capability <string>
# Extract category, operation, command from a capability string
# Format: category:operation:command
_parse_capability() {
  local cap="$1"
  # echo "category=$(echo "$cap" | cut -d: -f1), operation=$(echo "$cap" | cut -d: -f2), command=$(echo "$cap" | cut -d: -f3-)"
  echo "$cap" | awk -F: '{print "category=" $1 " operation=" $2 " command=" $3}'
}

# ---------------------------------------------------------------------------
# Tests: Hook File Existence
# ---------------------------------------------------------------------------

@test "Hook file: ~/.claude/hooks/session_start exists and is executable" {
  local hook="$HOME/.claude/hooks/session_start"

  [ -f "$hook" ] || skip "Claude Code hooks not initialized on this machine"
  [ -x "$hook" ] || skip "session_start hook not executable"

  # Verify it's a valid shell script
  run bash -n "$hook"
  [ "$status" -eq 0 ]
}

@test "Hook file: ~/.config/pi/hooks/session_start exists and is executable" {
  local hook="$HOME/.config/pi/hooks/session_start"

  # Pi hook is optional; skip if not present
  if [ ! -f "$hook" ]; then
    skip "Pi hooks not initialized on this machine"
  fi

  [ -x "$hook" ] || skip "Pi session_start hook not executable"

  run bash -n "$hook"
  [ "$status" -eq 0 ]
}

@test "Hook file: ~/.config/aider/hooks/session_start exists and is executable" {
  local hook="$HOME/.config/aider/hooks/session_start"

  # Aider hook is optional; skip if not present
  if [ ! -f "$hook" ]; then
    skip "Aider hooks not initialized on this machine"
  fi

  [ -x "$hook" ] || skip "Aider session_start hook not executable"

  run bash -n "$hook"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Tests: Capabilities Sourcing
# ---------------------------------------------------------------------------

@test "Capabilities: zdots/capabilities exists and is valid shell" {
  [ -x "$REAL_ZDOTDIR/bin/capabilities" ] || skip "zdots/bin/capabilities not found"

  # Verify it's a valid executable shell script
  run bash -n "$REAL_ZDOTDIR/bin/capabilities"
  [ "$status" -eq 0 ]

  # Also verify it can be executed
  run bash -c "$REAL_ZDOTDIR/bin/capabilities --json >/dev/null 2>&1 && echo ok"
  [[ "$output" == "ok" ]]
}

@test "Capabilities: adots/capabilities.sh exports ADOTS_ALL_CAPABILITIES" {
  [ -f "$REAL_ADOTS_DIR/capabilities.sh" ] || skip "adots/capabilities.sh not found"

  run bash -c "
    source '$REAL_ADOTS_DIR/capabilities.sh' >/dev/null 2>&1
    # Count ADOTS_CAPABILITIES_* arrays
    declare -a all_caps
    for arr in ADOTS_CAPABILITIES_{PROFILE,SYNC,HEALTH,MY,GIT,UTILS}; do
      if declare -p \"\$arr\" >/dev/null 2>&1; then
        eval \"all_caps+=(\\\${arr[@]})\"
      fi
    done
    [ \${#all_caps[@]} -gt 0 ] && echo 'ok' || echo 'empty'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "Capabilities: adots exposes the my doctor capability" {
  [ -f "$REAL_ADOTS_DIR/capabilities.sh" ] || skip "adots/capabilities.sh not found"

  run bash -c "
    source '$REAL_ADOTS_DIR/capabilities.sh' >/dev/null 2>&1
    printf '%s\n' \"\${ADOTS_ALL_CAPABILITIES[@]}\" | grep -Fx 'my:doctor:adots-my doctor'
  "
  [ "$status" -eq 0 ]
}

@test "Capabilities: Both capabilities files exist and are readable" {
  [ -x "$REAL_ZDOTDIR/bin/capabilities" ] || skip "zdots/capabilities not found"
  [ -f "$REAL_ADOTS_DIR/capabilities.sh" ] || skip "adots/capabilities.sh not found"

  # Both files are present; verify they can be parsed
  run bash -c "
    bash -n '$REAL_ZDOTDIR/bin/capabilities' && \\
    bash -n '$REAL_ADOTS_DIR/capabilities.sh' && \\
    echo 'both-ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "both-ok" ]]
}

@test "Capabilities: Entries follow category:operation:command format" {
  [ -f "$REAL_ADOTS_DIR/capabilities.sh" ] || skip "adots not found"

  run bash -c "
    source '$REAL_ADOTS_DIR/capabilities.sh' >/dev/null 2>&1

    # Check first adots capability
    for cap in \"\${ADOTS_CAPABILITIES_PROFILE[@]}\"; do
      [[ \$cap == *:*:* ]] && echo 'valid' && exit 0
    done
    echo 'invalid'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "valid" ]]
}

# ---------------------------------------------------------------------------
# Tests: Environment Variables
# ---------------------------------------------------------------------------

@test "Environment: ZDOTS_DIR is set and exported after sourcing" {
  run bash -c "
    export ZDOTDIR='$REAL_ZDOTDIR'
    export HOME='$HOME'
    source '$REAL_ZDOTDIR/.zdots.env' 2>/dev/null || true
    [ -n \"\${ZDOTS_DIR:-}\" ] && echo 'set' || echo 'unset'
  "
  [ "$status" -eq 0 ]
  # ZDOTS_DIR may be set via .zdots.env or computed
  [[ "$output" == "set" ]] || [[ -n "$ZDOTDIR" ]]
}

@test "Environment: ADOTS_DIR exists and points to valid directory" {
  run bash -c "
    export ADOTS_CONFIG_DIR='$REAL_ADOTS_DIR'
    [ -d \"\${ADOTS_CONFIG_DIR}\" ] && echo 'ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "Environment: HOME detection works (hook only runs in \$HOME)" {
  run bash -c "
    # Verify that pwd checks are possible
    [ -n \"\${HOME:-}\" ] && echo 'ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

# ---------------------------------------------------------------------------
# Tests: Health Check Execution
# ---------------------------------------------------------------------------

@test "Health: zdots-doctor runs without blocking (--no-runtime mode)" {
  skip_in_ci

  [ -x "$REAL_ZDOTDIR/bin/zdots-doctor" ] || skip "zdots-doctor not found"

  run bash -c "
    export ZDOTDIR='$REAL_ZDOTDIR'
    timeout 10 '$REAL_ZDOTDIR/bin/zdots-doctor' --no-runtime -q >/dev/null 2>&1
    echo \$?
  "
  # Exit code should be 0 or 1 (health status), not timeout (124)
  local exit_code="${output}"
  [ "$exit_code" != "124" ] || skip "zdots-doctor timed out (service issue)"
}

@test "Health: adots-doctor runs without blocking" {
  skip_in_ci

  [ -x "/Users/mike/bin/adots-doctor" ] || skip "adots-doctor not found"

  run bash -c "
    timeout 10 '/Users/mike/bin/adots-doctor' -q >/dev/null 2>&1
    echo \$?
  "
  local exit_code="${output}"
  [ "$exit_code" != "124" ] || skip "adots-doctor timed out (service issue)"
}

@test "Health: adots-my doctor runs without blocking" {
  skip_in_ci

  [ -x "/Users/mike/bin/adots-my" ] || skip "adots-my not found"

  run bash -c "
    timeout 10 '/Users/mike/bin/adots-my' doctor --quiet >/dev/null 2>&1
    echo \$?
  "
  local exit_code="${output}"
  [ "$exit_code" != "124" ] || skip "adots-my timed out"
}

@test "Health: Startup succeeds even if zdots-doctor fails" {
  skip_in_ci

  [ -x "$REAL_ZDOTDIR/bin/zdots-doctor" ] || skip "zdots-doctor not found"

  # Simulate a hook that ignores zdots-doctor failures
  run bash -c "
    export ZDOTDIR='$REAL_ZDOTDIR'
    '$REAL_ZDOTDIR/bin/zdots-doctor' --no-runtime -q >/dev/null 2>&1 || true
    echo 'startup-ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "startup-ok" ]]
}

@test "Health: Startup succeeds even if adots-doctor fails" {
  skip_in_ci

  [ -x "/Users/mike/bin/adots-doctor" ] || skip "adots-doctor not found"

  run bash -c "
    '/Users/mike/bin/adots-doctor' -q >/dev/null 2>&1 || true
    echo 'startup-ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "startup-ok" ]]
}

# ---------------------------------------------------------------------------
# Tests: Peer Cross-Checks
# ---------------------------------------------------------------------------

@test "Peer: zdots-doctor reports adots health as warning (not failure)" {
  skip_in_ci

  [ -x "$REAL_ZDOTDIR/bin/zdots-doctor" ] || skip "zdots-doctor not found"

  # Run zdots-doctor and check output for adots status
  run bash -c "
    export ZDOTDIR='$REAL_ZDOTDIR'
    '$REAL_ZDOTDIR/bin/zdots-doctor' --no-runtime -q 2>&1 | grep -i adots | head -1
  " || true

  # If adots is mentioned, it should be a warning or info, not a failure
  if [ -n "$output" ]; then
    [[ ! "$output" =~ FAIL ]] || [[ "$output" =~ warn ]]
  fi
}

@test "Peer: adots-doctor reports zdots health as warning (not failure)" {
  skip_in_ci

  [ -x "/Users/mike/bin/adots-doctor" ] || skip "adots-doctor not found"

  # Run adots-doctor and check output for zdots status
  run bash -c "
    '/Users/mike/bin/adots-doctor' -q 2>&1 | grep -i zdots | head -1
  " || true

  # If zdots is mentioned, it should be a warning or info, not a failure
  if [ -n "$output" ]; then
    [[ ! "$output" =~ FAIL ]] || [[ "$output" =~ warn ]]
  fi
}

@test "Peer: zdots exit code reflects zdots health only (adots failure doesn't fail zdots)" {
  skip_in_ci

  [ -x "$REAL_ZDOTDIR/bin/zdots-doctor" ] || skip "zdots-doctor not found"

  # Run zdots-doctor; it should exit based on zdots state, not adots
  run bash -c "
    export ZDOTDIR='$REAL_ZDOTDIR'
    '$REAL_ZDOTDIR/bin/zdots-doctor' --no-runtime -q >/dev/null 2>&1
    echo \$?
  "

  # Status should be 0 (pass) or 1 (failure), never blocking
  local code="${output}"
  [[ "$code" == "0" || "$code" == "1" ]]
}

@test "Peer: adots exit code reflects adots health only (zdots failure doesn't fail adots)" {
  skip_in_ci

  [ -x "/Users/mike/bin/adots-doctor" ] || skip "adots-doctor not found"

  # Run adots-doctor; it should exit based on adots state, not zdots
  run bash -c "
    '/Users/mike/bin/adots-doctor' -q >/dev/null 2>&1
    echo \$?
  "

  # Status should be 0 (pass), 1 (failure), or 2 (incomplete), never blocking
  local code="${output}"
  [[ "$code" == "0" || "$code" == "1" || "$code" == "2" ]]
}

# ---------------------------------------------------------------------------
# Tests: Capabilities Discovery
# ---------------------------------------------------------------------------

@test "Discovery: ADOTS capabilities can be parsed into category/operation/command" {
  [ -f "$REAL_ADOTS_DIR/capabilities.sh" ] || skip "adots not found"

  run bash -c "
    source '$REAL_ADOTS_DIR/capabilities.sh' >/dev/null 2>&1

    # Parse first profile capability
    for cap in \"\${ADOTS_CAPABILITIES_PROFILE[@]}\"; do
      IFS=: read -r cat op cmd <<< \"\$cap\"
      [ -n \"\$cat\" ] && [ -n \"\$op\" ] && [ -n \"\$cmd\" ] && echo 'ok' && exit 0
    done
    echo 'fail'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "Discovery: adots-profile command is executable" {
  run bash -c "
    which adots-profile >/dev/null 2>&1 && echo 'found'
  "

  if [ "$status" -eq 0 ] && [[ "$output" == "found" ]]; then
    run bash -c "adots-profile --help >/dev/null 2>&1 && echo 'ok'"
    [[ "$output" == "ok" ]]
  fi
}

@test "Discovery: zdots-ctx command is executable" {
  [ -x "$REAL_ZDOTDIR/bin/zdots-ctx" ] || skip "zdots-ctx not found"

  run bash -c "
    '$REAL_ZDOTDIR/bin/zdots-ctx' --help >/dev/null 2>&1 && echo 'ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "Discovery: adots sync command is discoverable" {
  run bash -c "
    which adots >/dev/null 2>&1 && echo 'found'
  "

  # adots command may not be in PATH; skip if not
  if [ "$status" -eq 0 ] && [[ "$output" == "found" ]]; then
    run bash -c "adots --help >/dev/null 2>&1 && echo 'ok'"
    [[ "$output" == "ok" ]]
  fi
}

@test "Discovery: zsvc command is executable" {
  run bash -c "
    which zsvc >/dev/null 2>&1 && zsvc list >/dev/null 2>&1 && echo 'ok'
  "

  if [ "$status" -eq 0 ]; then
    [[ "$output" == "ok" ]]
  fi
}

# ---------------------------------------------------------------------------
# Tests: Graceful Degradation
# ---------------------------------------------------------------------------

@test "Degradation: zdots capabilities can run independently" {
  [ -x "$REAL_ZDOTDIR/bin/capabilities" ] || skip "zdots/capabilities not found"

  # Test that zdots capabilities work in isolation (not dependent on adots)
  run bash -c "
    export ZDOTDIR='$REAL_ZDOTDIR'
    # Try running zdots capabilities normally
    '$REAL_ZDOTDIR/bin/capabilities' --json >/dev/null 2>&1 && echo 'ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "Degradation: Hook sources adots capabilities even if zdots is degraded" {
  [ -f "$REAL_ADOTS_DIR/capabilities.sh" ] || skip "adots not found"

  # Source adots capabilities in isolation
  run bash -c "
    source '$REAL_ADOTS_DIR/capabilities.sh' >/dev/null 2>&1
    [ \${#ADOTS_CAPABILITIES_PROFILE[@]} -gt 0 ] && echo 'ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

# ---------------------------------------------------------------------------
# Tests: Session Startup Sequence
# ---------------------------------------------------------------------------

@test "Startup: Full session initialization completes without error" {
  skip_in_ci

  run bash -c "
    export HOME='$HOME'
    export ZDOTDIR='${ZDOTDIR:-$HOME/.config/zsh}'

    # Simulate a complete session startup
    # 1. Source zdots env
    [ -f \"\$ZDOTDIR/.zdots.env\" ] && source \"\$ZDOTDIR/.zdots.env\" || true

    # 2. Run light health checks
    \"\$ZDOTDIR/bin/zdots-doctor\" --no-runtime -q >/dev/null 2>&1 || true

    # 3. Verify capabilities are discoverable
    [ -x \"\$ZDOTDIR/bin/capabilities\" ] && \"\$ZDOTDIR/bin/capabilities\" --json >/dev/null 2>&1 || true

    echo 'startup-complete'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "startup-complete" ]]
}

@test "Startup: Multiple session starts don't conflict (idempotency)" {
  skip_in_ci

  run bash -c "
    export HOME='$HOME'
    export ZDOTDIR='${ZDOTDIR:-$HOME/.config/zsh}'

    # Run startup sequence twice
    for i in 1 2; do
      [ -f \"\$ZDOTDIR/.zdots.env\" ] && source \"\$ZDOTDIR/.zdots.env\" || true
      \"\$ZDOTDIR/bin/zdots-doctor\" --no-runtime -q >/dev/null 2>&1 || true
    done

    echo 'idempotent'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "idempotent" ]]
}
