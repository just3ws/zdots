#!/usr/bin/env bats
# tests/tx.bats — bin/tx: sessions from a shell, from inside tmux, and at terminal launch.
# Real tmux on a private socket; calls that need a terminal (attach, switch,
# picker, landing attach) are logged by the wrapper instead of run.

setup() {
  load "setup.bash"
  setup_environment
  command -v tmux >/dev/null 2>&1 || skip "tmux not installed"
  SOCK="tx-test-$$-${BATS_TEST_NUMBER}"
  LOG="$BATS_TEST_TMPDIR/tmux.log"
  WRAP="$BATS_TEST_TMPDIR/tmux-wrap"
  cat >"$WRAP" <<EOF
#!/usr/bin/env bash
case "\$1" in
  attach-session|switch-client|choose-tree) echo "\$*" >>"$LOG"; exit 0 ;;
  list-clients) [[ -n "\${FAKE_CLIENT:-}" ]] && echo x; exit 0 ;;
  new-session)
    [[ " \$* " == *" -A "* ]] && { echo "\$*" >>"$LOG"; exit 0; }
    # Grouped landing view: run it for real, detached (no terminal in tests).
    [[ " \$* " == *" -t "* && " \$* " != *" -d "* ]] && { echo "\$*" >>"$LOG"; shift; exec tmux -L "$SOCK" -f /dev/null new-session -d "\$@"; } ;;
esac
exec tmux -L "$SOCK" -f /dev/null "\$@"
EOF
  chmod +x "$WRAP"
  export TX_TMUX="$WRAP"
  unset TMUX ZDOTS_TMUX_LANDING
}

teardown() {
  tmux -L "$SOCK" kill-server 2>/dev/null || true
}

@test "tx --help prints usage" {
  run "$REPO_ROOT/bin/tx" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: tx"* ]]
  [[ "$output" == *"--landing"* ]]
}

@test "tx rejects unknown options" {
  run "$REPO_ROOT/bin/tx" --bogus
  [ "$status" -eq 2 ]
}

@test "tx <name> outside tmux creates the session in this directory and attaches" {
  cd "$BATS_TEST_TMPDIR"
  run "$REPO_ROOT/bin/tx" alpha
  [ "$status" -eq 0 ]
  tmux -L "$SOCK" has-session -t =alpha
  [ "$(tmux -L "$SOCK" list-sessions -F '#{session_name} #{session_path}' | grep '^alpha ')" = "alpha $PWD" ]
  grep -qx 'attach-session -t =alpha' "$LOG"
}

@test "tx <name> inside tmux switches the client instead of nesting" {
  export TMUX="/tmp/fake,1,0"
  run "$REPO_ROOT/bin/tx" beta
  [ "$status" -eq 0 ]
  tmux -L "$SOCK" has-session -t =beta
  grep -qx 'switch-client -t =beta' "$LOG"
  ! grep -q 'attach-session' "$LOG"
}

@test "tx <name> reuses an existing session" {
  tmux -L "$SOCK" -f /dev/null new-session -d -s gamma
  run "$REPO_ROOT/bin/tx" gamma
  [ "$status" -eq 0 ]
  [ "$(tmux -L "$SOCK" list-sessions -F '#{session_name}' | grep -c '^gamma$')" -eq 1 ]
}

@test "tx - inside tmux switches back to the previous session" {
  export TMUX="/tmp/fake,1,0"
  run "$REPO_ROOT/bin/tx" -
  [ "$status" -eq 0 ]
  grep -qx 'switch-client -l' "$LOG"
}

@test "tx - falls back to the landing session when the previous one is gone" {
  export TMUX="/tmp/fake,1,0"
  fail="$BATS_TEST_TMPDIR/tmux-fail-last"
  cat >"$fail" <<EOF
#!/usr/bin/env bash
[[ "\$*" == "switch-client -l" ]] && { echo "can't find last session" >&2; exit 1; }
echo "\$*" >>"$LOG"
EOF
  chmod +x "$fail"
  TX_TMUX="$fail" run "$REPO_ROOT/bin/tx" -
  [ "$status" -eq 0 ]
  grep -qx 'switch-client -t =main' "$LOG"
}

@test "tx - outside tmux explains it only works inside tmux" {
  run "$REPO_ROOT/bin/tx" -
  [ "$status" -eq 2 ]
  [[ "$output" == *"inside tmux"* ]]
}

@test "tx with no name inside tmux opens the session picker" {
  export TMUX="/tmp/fake,1,0"
  run "$REPO_ROOT/bin/tx"
  [ "$status" -eq 0 ]
  grep -qx 'choose-tree -Zs' "$LOG"
}

@test "tx with no name outside tmux lists sessions" {
  tmux -L "$SOCK" -f /dev/null new-session -d -s delta
  run "$REPO_ROOT/bin/tx"
  [ "$status" -eq 0 ]
  [[ "$output" == *"delta"* ]]
}

@test "tx --landing attaches the landing session when no client shows it" {
  run "$REPO_ROOT/bin/tx" --landing
  [ "$status" -eq 0 ]
  grep -qx 'new-session -A -s main' "$LOG"
}

@test "tx --landing honours ZDOTS_TMUX_LANDING" {
  ZDOTS_TMUX_LANDING=work run "$REPO_ROOT/bin/tx" --landing
  [ "$status" -eq 0 ]
  grep -qx 'new-session -A -s work' "$LOG"
}

@test "tx --landing opens a durable window in the landing session when a client already shows it" {
  tmux -L "$SOCK" -f /dev/null new-session -d -s main 'sleep 60'
  before="$(tmux -L "$SOCK" list-windows -t =main | wc -l)"
  cd "$BATS_TEST_TMPDIR"
  FAKE_CLIENT=1 run "$REPO_ROOT/bin/tx" --landing
  [ "$status" -eq 0 ]
  # The new window lives in main (so it outlives the terminal tab) ...
  [ "$(tmux -L "$SOCK" list-windows -t =main | wc -l)" -eq $((before + 1)) ]
  [ "$(tmux -L "$SOCK" list-windows -t =main -F '#{pane_current_path}' | tail -1)" = "$(pwd -P)" ]
  # ... through its own grouped view.
  grep -q -- 'new-session -t =main ; new-window' "$LOG"
  [ "$(tmux -L "$SOCK" list-sessions -F '#{session_name} #{session_group}' | grep -c ' main$')" -eq 2 ]
  ! grep -q -- '-A -s main' "$LOG"
}

@test "tx --landing prunes views nobody shows, keeping their windows in the landing session" {
  tmux -L "$SOCK" -f /dev/null new-session -d -s main 'sleep 60'
  tmux -L "$SOCK" new-session -d -t =main -s main-7
  tmux -L "$SOCK" new-window -d -t =main 'sleep 60'
  tmux -L "$SOCK" new-session -d -s other 'sleep 60'
  windows="$(tmux -L "$SOCK" list-windows -t =main | wc -l)"
  FAKE_CLIENT=1 run "$REPO_ROOT/bin/tx" --landing
  [ "$status" -eq 0 ]
  ! tmux -L "$SOCK" has-session -t =main-7
  tmux -L "$SOCK" has-session -t =other
  # Pruning the old view kept every window; the new view added one.
  [ "$(tmux -L "$SOCK" list-windows -t =main | wc -l)" -eq $((windows + 1)) ]
}

@test "tx --landing falls back to a login shell when tmux is missing" {
  shell="$BATS_TEST_TMPDIR/fake-shell"
  printf '#!/bin/sh\necho "login-shell $*"\n' >"$shell"
  chmod +x "$shell"
  TX_TMUX="$BATS_TEST_TMPDIR/no-such-tmux" SHELL="$shell" run "$REPO_ROOT/bin/tx" --landing
  [ "$status" -eq 0 ]
  [ "$output" = "login-shell -l" ]
}
