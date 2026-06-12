#!/usr/bin/env bats
# tests/log_rotate.bats — log-rotate CLI contract and behavior tests

setup() {
  load "setup.bash"
  setup_environment
  TMP_DIR="$(mktemp -d)"
  FAKE_LOG="$TMP_DIR/fake-service.log"
  FAKE_PLIST="$HOME/Library/LaunchAgents/com.zdots.fake-service.plist"
  # Write a small fake log
  printf 'line1\nline2\nline3\n' > "$FAKE_LOG"
}

teardown() {
  rm -rf "$TMP_DIR"
  rm -f "$FAKE_PLIST"
}

# ── Interface contract ────────────────────────────────────────────────────────

@test "log-rotate: --help exits 0" {
  run log-rotate --help
  [ "$status" -eq 0 ]
}

@test "log-rotate: --help produces output" {
  run log-rotate --help
  [ "${#lines[@]}" -gt 5 ]
}

@test "log-rotate: no args exits non-zero with usage" {
  run log-rotate
  [ "$status" -ne 0 ]
  [[ "$output" =~ "service name required" ]]
}

@test "log-rotate: unknown flag exits non-zero" {
  run log-rotate --no-such-flag
  [ "$status" -ne 0 ]
}

# ── Plist / log detection ─────────────────────────────────────────────────────

@test "log-rotate: missing plist exits non-zero" {
  run log-rotate no-such-service-xyz
  [ "$status" -ne 0 ]
  [[ "$output" =~ "plist not found" ]]
}

@test "log-rotate: dry-run detects log path from plist" {
  # Write a minimal plist pointing at our fake log
  defaults write "$HOME/Library/LaunchAgents/com.zdots.fake-service" \
    StandardErrorPath "$FAKE_LOG"
  run log-rotate fake-service --dry-run
  # dry-run exits 1 by convention; output must name the log
  [[ "$output" =~ "$FAKE_LOG" ]]
}

# ── Rotation behavior ─────────────────────────────────────────────────────────

@test "log-rotate: creates gzip archive and truncates log" {
  defaults write "$HOME/Library/LaunchAgents/com.zdots.fake-service" \
    StandardErrorPath "$FAKE_LOG"
  run log-rotate fake-service
  [ "$status" -eq 0 ]
  # Active log truncated to zero
  [ "$(wc -c < "$FAKE_LOG")" -eq 0 ]
  # Archive created alongside log
  local archives=("$TMP_DIR"/fake-service.log.*.gz)
  [ "${#archives[@]}" -eq 1 ]
  [ -f "${archives[0]}" ]
}

@test "log-rotate: archive is valid gzip" {
  defaults write "$HOME/Library/LaunchAgents/com.zdots.fake-service" \
    StandardErrorPath "$FAKE_LOG"
  log-rotate fake-service >/dev/null 2>&1
  local archive
  archive="$(ls "$TMP_DIR"/fake-service.log.*.gz 2>/dev/null | head -1)"
  run gzip -t "$archive"
  [ "$status" -eq 0 ]
}

@test "log-rotate: archive preserves original content" {
  defaults write "$HOME/Library/LaunchAgents/com.zdots.fake-service" \
    StandardErrorPath "$FAKE_LOG"
  log-rotate fake-service >/dev/null 2>&1
  local archive
  archive="$(ls "$TMP_DIR"/fake-service.log.*.gz 2>/dev/null | head -1)"
  run gunzip -c "$archive"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "line1" ]]
}
