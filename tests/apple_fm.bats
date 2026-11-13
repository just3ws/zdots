#!/usr/bin/env bats
# tests/apple_fm.bats — Apple on-device model via fm, locked to the device.
# A stub fm (ZDOTS_FM_BIN) records its argv; nothing here runs a real model.

setup() {
  load "setup.bash"
  setup_environment
  export FM_LOG="$BATS_TEST_TMPDIR/fm.log"
  export FM_STUB="$BATS_TEST_TMPDIR/fm"
  export FM_PROVIDER="(none)" FM_MODEL="(none)" FM_SYSTEM="✓"
  cat > "$FM_STUB" <<'SH'
#!/bin/sh
echo "$*" >> "$FM_LOG"
case "$1 $2" in
  "models "*) echo "  $FM_SYSTEM system (AFM 3 Core Advanced)"; echo "  ✗ pcc" ;;
  "config get") [ "$3" = default-model-provider ] && echo "$FM_PROVIDER" || echo "$FM_MODEL" ;;
  "config list") echo "Default-model-provider  $FM_PROVIDER" ;;
  "respond "*) cat >/dev/null; echo "stub reply" ;;
esac
SH
  chmod +x "$FM_STUB"
}

# Run zsh with the provider sourced and hygiene/gate stubbed as pass-through.
run_fm() {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT' ZDOTS_FM_BIN='$FM_STUB'
    zdots_ai_gate_check() { return 0; }
    zdots_message_hygiene() { cat; }
    phi_scrub() { cat; }
    source '$REPO_ROOT/providers/tools/apple-fm.zsh'
    $1
  "
}

@test "guard passes when the on-device model is available and fm config is clean" {
  run_fm "zdots_fm_guard"
  [ "$status" -eq 0 ]
}

@test "guard reports a missing fm cleanly" {
  FM_STUB="$BATS_TEST_TMPDIR/absent"
  run_fm "zdots_fm_guard"
  [ "$status" -eq 127 ]
  [[ "$output" == *"not found"* ]]
}

@test "guard reports an unavailable on-device model cleanly" {
  FM_SYSTEM="✗"
  run_fm "zdots_fm_guard"
  [ "$status" -eq 127 ]
  [[ "$output" == *"unavailable"* ]]
}

@test "guard refuses when fm has a default model provider" {
  FM_PROVIDER="https://example.invalid/v1"
  run_fm "zdots_fm_guard"
  [ "$status" -eq 3 ]
  [[ "$output" == *"refusing"* ]]
}

@test "guard refuses when fm's default model is not the on-device one" {
  FM_MODEL="pcc"
  run_fm "zdots_fm_guard"
  [ "$status" -eq 3 ]
}

@test "guard accepts system as fm's default model" {
  FM_MODEL="system"
  run_fm "zdots_fm_guard"
  [ "$status" -eq 0 ]
}

@test "zapfel pins the on-device model and sends the prompt on stdin" {
  run_fm "zapfel 'summarize secret-free text' </dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stub reply"* ]]
  grep -q '^respond --model system --no-stream$' "$FM_LOG"
  ! grep -q 'pcc\|secret-free' "$FM_LOG"
}

@test "zapfel does not run fm respond when the guard refuses" {
  FM_PROVIDER="https://example.invalid/v1"
  run_fm "zapfel 'hello' </dev/null"
  [ "$status" -eq 3 ]
  ! grep -q '^respond' "$FM_LOG"
}

@test "zapfel refuses fm options such as --model" {
  run_fm "zapfel --model pcc 'hello' </dev/null"
  [ "$status" -eq 2 ]
  ! grep -q '^respond' "$FM_LOG"
}

@test "zai --apple selects the apple engine" {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT'
    source '$REPO_ROOT/providers/tools/router.zsh'
    ZAI_NO_CLASSIFY=1 zai --dry-run --apple 'draft a commit message'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"engine=apple"* ]]
}

@test "aider weak-model settings point only at loopback" {
  run_fm "
    _zdots_fm_aider_files 44611 '$BATS_TEST_TMPDIR/settings.yml' '$BATS_TEST_TMPDIR/meta.json' /nonexistent
    cat '$BATS_TEST_TMPDIR/settings.yml'
    jq -e '.\"openai/system\".max_input_tokens' '$BATS_TEST_TMPDIR/meta.json'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"name: openai/system"* ]]
  [[ "$output" == *"api_base: http://127.0.0.1:44611/v1"* ]]
  [[ "$output" == *"stream: false"* ]]
}

@test "aider weak-model metadata keeps the existing entries" {
  echo '{"openai/local":{"max_input_tokens":32768}}' > "$BATS_TEST_TMPDIR/base.json"
  run_fm "
    _zdots_fm_aider_files 44611 '$BATS_TEST_TMPDIR/s.yml' '$BATS_TEST_TMPDIR/m.json' '$BATS_TEST_TMPDIR/base.json'
    jq -e '.\"openai/local\".max_input_tokens == 32768 and .\"openai/system\" != null' '$BATS_TEST_TMPDIR/m.json'
  "
  [ "$status" -eq 0 ]
}

@test "fm serve start does nothing when the guard refuses" {
  FM_PROVIDER="https://example.invalid/v1"
  run_fm "zdots_fm_serve_start"
  [ "$status" -eq 3 ]
  ! grep -q '^serve' "$FM_LOG"
}

# zaider with stubbed init/aider and a fake serve start (no real server).
run_zaider() {
  run zsh -c "
    export ZDOTDIR='$REPO_ROOT' ZDOTS_FM_BIN='$FM_STUB' TMPDIR='$BATS_TEST_TMPDIR'
    source '$REPO_ROOT/providers/tools/aider.zsh'
    source '$REPO_ROOT/providers/tools/apple-fm.zsh'
    zdots_aider_init() { return 0; }
    zdots_trace_log() { :; }
    zdots_fm_serve_start() { typeset -g ZDOTS_FM_SERVE_PID=999999 ZDOTS_FM_SERVE_PORT=44612; }
    zdots_fm_serve_stop() { print stopped; unset ZDOTS_FM_SERVE_PID ZDOTS_FM_SERVE_PORT; }
    aider() {
      print \"weak=\${AIDER_WEAK_MODEL:-unset}\"
      [[ -n \"\${AIDER_MODEL_SETTINGS_FILE:-}\" ]] && cat \"\$AIDER_MODEL_SETTINGS_FILE\"
      print \"settings=\${AIDER_MODEL_SETTINGS_FILE:-unset}\"
      return 7
    }
    $1
    rc=\$?
    print \"left=\$(ls -d '$BATS_TEST_TMPDIR'/zaider-fm.* 2>/dev/null | wc -l | tr -d ' ')\"
    exit \$rc
  "
}

@test "zaider routes the weak model to loopback fm for the session, then cleans up" {
  run_zaider "zaider --message hi"
  [ "$status" -eq 7 ]
  [[ "$output" == *"weak=openai/system"* ]]
  [[ "$output" == *"api_base: http://127.0.0.1:44612/v1"* ]]
  [[ "$output" == *"stopped"* ]]
  [[ "$output" == *"left=0"* ]]
}

@test "ZDOTS_AIDER_WEAK=local keeps zaider off fm" {
  run_zaider "ZDOTS_AIDER_WEAK=local zaider"
  [ "$status" -eq 7 ]
  [[ "$output" == *"weak=unset"* ]]
  [[ "$output" != *"stopped"* ]]
}

@test "zaider falls back to the local weak model when the guard refuses" {
  run_zaider "zdots_fm_serve_start() { return 3; }; zaider"
  [ "$status" -eq 7 ]
  [[ "$output" == *"weak=unset"* ]]
  [[ "$output" == *"refused"* ]]
}
