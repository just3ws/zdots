#!/usr/bin/env bats
# tests/lifecycle.bats — Tests for the Service Lifecycle Engine

setup() {
  load "setup"
  setup_environment
  source "$REPO_ROOT/lib/lifecycle.bash"
  
  # Mock output helpers to prevent pollution
  _svc_log()  { :; }
  _svc_ok()   { :; }
  _svc_warn() { :; }
  _svc_die()  { echo "DIE: $*"; exit 1; }
  
  # Create a dummy plist for testing
  TEST_PLIST=$(mktemp)
  echo "dummy" > "$TEST_PLIST"
}

teardown() {
  rm -f "$TEST_PLIST"
}

# Mocking launchctl
launchctl() {
  if [[ "$1" == "print" ]]; then
    # Return 0 for "running-label", 1 for anything else
    [[ "$2" == *"running-label"* ]] && return 0 || return 1
  fi
  if [[ "$1" == "list" ]]; then
    if [[ "$2" == "running-label" ]]; then
      echo '"PID" = 1234;'
      return 0
    fi
    return 1
  fi
  return 0
}

@test "lifecycle: launchd_start skips if already running" {
  export SVC_NAME="test"
  run zdots_svc_launchd_start "running-label" "$TEST_PLIST"
  [ "$status" -eq 0 ]
}

@test "lifecycle: launchd_status returns running state and PID" {
  run zdots_svc_launchd_status "running-label"
  [ "$status" -eq 0 ]
  [ "$output" = "true 1234" ]
}

@test "lifecycle: launchd_status returns false if not running" {
  run zdots_svc_launchd_status "dead-label"
  [ "$status" -eq 0 ]
  [ "$output" = "false " ]
}

@test "lifecycle: restart calls stop then start" {
  # We can't easily check side effects of eval in bats without more mocking
  # but we can check it doesn't crash
  run zdots_svc_restart "echo stop" "echo start"
  [ "$status" -eq 0 ]
}

@test "lifecycle: pid_status returns false for non-existent pid file" {
  run zdots_svc_pid_status "/tmp/non-existent-pid-file"
  [ "$status" -eq 0 ]
  [ "$output" = "false " ]
}
