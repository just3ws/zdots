#!/usr/bin/env bats
# tests/yazi.bats — the `y` wrapper in conf.d/71-shell-tools.zsh: launch yazi,
# then leave the shell in the directory yazi was in at quit.
# A fake yazi stands in for the real one and writes the --cwd-file.

setup() {
  load "setup.bash"
  setup_environment
  FAKEBIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$FAKEBIN" "$BATS_TEST_TMPDIR/start" "$BATS_TEST_TMPDIR/dest"
  cat >"$FAKEBIN/yazi" <<'EOF'
#!/bin/sh
# Record the args, then report $YAZI_FAKE_CWD as the directory at quit.
echo "$*" >"$YAZI_FAKE_LOG"
for a in "$@"; do
  case "$a" in --cwd-file=*) printf '%s' "$YAZI_FAKE_CWD" >"${a#--cwd-file=}" ;; esac
done
EOF
  chmod +x "$FAKEBIN/yazi"
  export YAZI_FAKE_LOG="$BATS_TEST_TMPDIR/yazi.log"
  # Only the fake yazi and the system tools: the other tools in this file stay quiet.
  export PATH="$FAKEBIN:/usr/bin:/bin"
}

y_in() { # y_in <reported cwd> [args…] — run y from start/, print the shell's final $PWD
  local cwd="$1"
  shift
  YAZI_FAKE_CWD="$cwd" zsh -fc "cd '$BATS_TEST_TMPDIR/start' && source '$REPO_ROOT/conf.d/71-shell-tools.zsh' && y $* && print -r -- \$PWD"
}

@test "y: changes to the directory yazi was in at quit" {
  run y_in "$BATS_TEST_TMPDIR/dest"
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/dest" ]
}

@test "y: stays put when yazi reports no directory or one that is gone" {
  run y_in ""
  [ "$output" = "$BATS_TEST_TMPDIR/start" ]
  run y_in "$BATS_TEST_TMPDIR/no-such-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/start" ]
}

@test "y: passes its arguments to yazi and removes the cwd file" {
  run y_in "$BATS_TEST_TMPDIR/dest" /tmp
  [ "$status" -eq 0 ]
  read -r first cwdflag <"$YAZI_FAKE_LOG"
  [ "$first" = "/tmp" ]
  [ ! -e "${cwdflag#--cwd-file=}" ]
}

@test "y: is not defined when yazi is not installed" {
  run env PATH=/usr/bin:/bin zsh -fc "source '$REPO_ROOT/conf.d/71-shell-tools.zsh' && whence -w y"
  [ "$status" -ne 0 ]
}
