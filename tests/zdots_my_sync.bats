#!/usr/bin/env bats
# tests/zdots_my_sync.bats — zdots delegates ~/my structure checks to adots.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
}

@test "zdots-my-sync delegates to adots-my doctor with the configured my root" {
  mock_bin="$BATS_TEST_TMPDIR/bin"
  capture="$BATS_TEST_TMPDIR/adots-my.args"
  mkdir -p "$mock_bin"
  cat > "$mock_bin/adots-my" <<MOCK
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$capture"
exit 0
MOCK
  chmod +x "$mock_bin/adots-my"

  ZDOTS_MY_ROOT="$BATS_TEST_TMPDIR/my-root" PATH="$mock_bin:$PATH" run "$BIN/zdots-my-sync" --quiet

  [ "$status" -eq 0 ]
  run grep -Fx "doctor" "$capture"
  [ "$status" -eq 0 ]
  run grep -Fx -- "--my-root" "$capture"
  [ "$status" -eq 0 ]
  run grep -Fx "$BATS_TEST_TMPDIR/my-root" "$capture"
  [ "$status" -eq 0 ]
  run grep -Fx -- "--quiet" "$capture"
  [ "$status" -eq 0 ]
}

@test "zdots-my-sync json mode does not add a human preamble" {
  mock_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$mock_bin"
  cat > "$mock_bin/adots-my" <<'MOCK'
#!/usr/bin/env bash
printf '{"status":"pass"}\n'
exit 0
MOCK
  chmod +x "$mock_bin/adots-my"

  PATH="$mock_bin:$PATH" run "$BIN/zdots-my-sync" --json

  [ "$status" -eq 0 ]
  [ "$output" = '{"status":"pass"}' ]
}

@test "zdots-my-sync fails clearly when adots-my is unavailable" {
  mkdir -p "$BATS_TEST_TMPDIR/home"

  run bash -c '
    HOME="$1" PATH="/usr/bin:/bin" "$2" --quiet 2>&1
    printf "\nstatus=%s\n" "$?"
  ' _ "$BATS_TEST_TMPDIR/home" "$BIN/zdots-my-sync"

  [ "$status" -eq 0 ]
  [[ "$output" == *"status=127"* ]]
  [[ "$output" == *"adots-my not found"* ]]
}
