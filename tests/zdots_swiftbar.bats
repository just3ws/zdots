#!/usr/bin/env bats
# tests/zdots_swiftbar.bats — test suite for zdots-swiftbar (Z-288)

setup() {
  load "setup.bash"
  setup_environment
  export PATH="$REPO_ROOT/bin:$PATH"
}

@test "zdots-swiftbar: --help prints usage and exits 0" {
  run "$REPO_ROOT/bin/zdots-swiftbar" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: zdots-swiftbar" ]]
  [[ "$output" =~ "Standing Indicators:" ]]
  [[ "$output" =~ "Whisper:" ]]
}

@test "zdots-swiftbar: unknown argument exits 2" {
  run "$REPO_ROOT/bin/zdots-swiftbar" --invalid-flag
  [ "$status" -eq 2 ]
  [[ "$output" =~ "unknown argument" ]]
}

@test "zdots-swiftbar: emits valid SwiftBar dialect with rich transcription telemetry" {
  run "$REPO_ROOT/bin/zdots-swiftbar"
  [ "$status" -eq 0 ]

  # Menu bar line must contain platform health and transcription iconography
  first_line="${lines[0]}"
  [[ "$first_line" =~ (🟢|🟡|🔴|⚪) ]]
  [[ "$first_line" =~ 🎙️ ]]

  # Separator must exist on line 2
  [ "${lines[1]}" = "---" ]

  # Dropdown must contain featured transcription section
  [[ "$output" =~ "🎙️ Transcription:" ]]
  [[ "$output" =~ "Active Model:" ]]
  [[ "$output" =~ "Models on Disk:" ]]
  [[ "$output" =~ "Actions:" ]]

  # Dropdown must contain platform subsystems matrix
  [[ "$output" =~ "Platform Subsystems" ]]
  [[ "$output" =~ "AI Inference" ]]
  [[ "$output" =~ "Embeddings Engine" ]]
  [[ "$output" =~ "Message Bus" ]]

  # Dropdown must contain doctor and actions
  [[ "$output" =~ "Platform Doctor:" ]]
  [[ "$output" =~ "Run Doctor Now" ]]
  [[ "$output" =~ "Run Check Suite | bash=".*"/bin/check terminal=true" ]]
  [[ "$output" =~ "Refresh SwiftBar Pulse" ]]
}

@test "zdots-swiftbar: flags missing model cleanly when model file is nonexistent" {
  tmp_models="$(mktemp -d)"
  run env ZDOTS_WHISPER_MODELS_DIR="$tmp_models" ZDOTS_WHISPER_MODEL_FILE="nonexistent.bin" "$REPO_ROOT/bin/zdots-swiftbar"
  rm -rf "$tmp_models"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "🎙️⚠️" ]]
  [[ "$output" =~ "missing model" ]]
}

@test "zdots-swiftbar: doctor status is decoupled from check suite rc" {
  state_dir="$(mktemp -d)"
  mkdir -p "$state_dir/zsh"
  printf "ts=2026-10-07T00:00:00\nrc=0\npass=43\nwarn=0\nfail=0\ncaps_errors=0\n" > "$state_dir/zsh/zdots-watch.state"
  printf "ts=2026-10-07T00:00:00\nrc=1\nfail|some test\n" > "$state_dir/zsh/zdots-watch-check.state"
  run env XDG_STATE_HOME="$state_dir" "$REPO_ROOT/bin/zdots-swiftbar"
  rm -rf "$state_dir"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Platform Doctor: 43 pass · 0 warn · 0 fail (Healthy)" ]]
  [[ "$output" =~ "Test Suite: rc=1" ]]
}
