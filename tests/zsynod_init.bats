#!/usr/bin/env bats

setup() {
  export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  TMP="$(mktemp -d)"
  export ZSYNOD_DIR="$TMP/zsynod"
  export ZDOTDIR="$REPO_ROOT"
}

teardown() { rm -rf "$TMP"; }

@test "zsynod init is quiet on a fresh ZSYNOD_DIR" {
  run --separate-stderr "$REPO_ROOT/bin/zsynod" init
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ -f "$ZSYNOD_DIR/members.json" ]
}
