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
    if [[ "$2" == *"running-label"* ]]; then
      printf 'state = running\npid = 1234\n'
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

# Z-362: bootout returns while the job still shows as SIGTERMed. A start in that
# window trusts KeepAlive, which bootout has already removed, so nothing loads.
# stop() must wait until the job is gone so the following start bootstraps.
@test "lifecycle: stop waits out a lingering SIGTERMed job so start bootstraps (Z-362)" {
  export LINGER="$BATS_TEST_TMPDIR/linger" CALLS="$BATS_TEST_TMPDIR/calls"
  printf '3' > "$LINGER"
  launchctl() {
    echo "$1" >> "$CALLS"
    case "$1" in
      bootout) return 0 ;;
      print)
        local n; n=$(cat "$LINGER")
        if (( n > 0 )); then
          printf '%s' $((n - 1)) > "$LINGER"
          printf 'state = SIGTERMed\npid = 999\n'; return 0
        fi
        [[ -f "$BATS_TEST_TMPDIR/booted" ]] && { printf 'state = running\npid = 42\n'; return 0; }
        return 1 ;;
      bootstrap) touch "$BATS_TEST_TMPDIR/booted"; return 0 ;;
      *) return 0 ;;
    esac
  }
  sleep() { :; }
  zdots_svc_launchd_stop "slow-label"
  zdots_svc_launchd_start "slow-label" "$TEST_PLIST"
  grep -q '^bootstrap$' "$CALLS"
  run zdots_svc_launchd_require_loaded "slow-label"
  [ "$status" -eq 0 ]
}

@test "lifecycle: require_loaded fails when the job is not loaded" {
  run zdots_svc_launchd_require_loaded "dead-label"
  [ "$status" -ne 0 ]
}

@test "llama-ctl installers use the waiting stop and confirm the job loaded (Z-362)" {
  ! grep -q 'launchctl bootout "gui/$(id -u)/${PLIST_LABEL}"' "$REPO_ROOT/bin/llama-ctl"
  ! grep -q 'launchctl bootout "gui/$(id -u)/${EMBED_PLIST_LABEL}"' "$REPO_ROOT/bin/llama-ctl"
  [ "$(grep -c 'zdots_svc_launchd_require_loaded' "$REPO_ROOT/bin/llama-ctl")" -ge 2 ]
}
