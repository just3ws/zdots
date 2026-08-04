#!/usr/bin/env bats
# tests/vault_doctor.bats — contract tests for zdots-vault-doctor (Z-192).

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin/zdots-vault-doctor"
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  export ZDOTDIR="$REPO_ROOT"
}

@test "vault-doctor: executable" {
  [ -x "$BIN" ]
}

@test "vault-doctor: --help exits 0 and does not scan or write state" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: zdots-vault-doctor"* ]]
  [ ! -d "$XDG_STATE_HOME/zsh/vault-doctor" ]
}

@test "vault-doctor: --self-check passes offline" {
  run "$BIN" --self-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"self-check OK"* ]]
}

@test "vault-doctor: scans a fixture corpus and emits valid JSON" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  mkdir -p "$BATS_TEST_TMPDIR/corpus"
  cat > "$BATS_TEST_TMPDIR/corpus/stale.md" <<'EOF'
---
updated: 2020-01-01
---
hi [dangling](nowhere.md) TODO
EOF
  run "$BIN" "$BATS_TEST_TMPDIR/corpus" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.queue | length == 1' >/dev/null
  echo "$output" | jq -e '.queue[0].action != "ok"' >/dev/null
}

@test "vault-doctor: --ack silences a finding until content changes" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  mkdir -p "$BATS_TEST_TMPDIR/corpus2"
  printf 'thin\n' > "$BATS_TEST_TMPDIR/corpus2/thin.md"
  "$BIN" "$BATS_TEST_TMPDIR/corpus2" --json >/dev/null

  run "$BIN" --ack "$BATS_TEST_TMPDIR/corpus2/thin.md"
  [ "$status" -eq 0 ]

  run "$BIN" "$BATS_TEST_TMPDIR/corpus2" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.queue | length == 0' >/dev/null

  run "$BIN" --history "$BATS_TEST_TMPDIR/corpus2/thin.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"new-asset"* ]]
  [[ "$output" == *"disposition"* ]]
}

@test "zdots-ctx: vault-doctor verb dispatches to zdots-vault-doctor" {
  run "$REPO_ROOT/bin/zdots-ctx" vault-doctor --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: zdots-vault-doctor"* ]]
}
