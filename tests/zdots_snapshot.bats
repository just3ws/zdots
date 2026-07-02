#!/usr/bin/env bats
# tests/zdots_snapshot.bats — capture/diff timeline contract (Z-191).

setup() {
  load "setup.bash"
  setup_environment
  export ZDOTS_SNAPSHOT_DIR="$BATS_TEST_TMPDIR/snaps"
  SNAP="$REPO_ROOT/bin/zdots-snapshot"
}

@test "snapshot: first capture stores stdout and propagates exit 0" {
  run "$SNAP" demo -- echo hello
  [ "$status" -eq 0 ]
  [ "$(cat "$ZDOTS_SNAPSHOT_DIR"/demo/*.txt)" = "hello" ]
}

@test "snapshot: second capture diffs against previous" {
  "$SNAP" demo -- echo one
  sleep 1
  run "$SNAP" demo -- echo two
  [ "$status" -eq 0 ]
  [[ "$output" == *"-one"* && "$output" == *"+two"* ]]
}

@test "snapshot: failing command's exit status propagates, capture kept" {
  run "$SNAP" demo -- bash -c 'echo partial; exit 7'
  [ "$status" -eq 7 ]
  [ "$(cat "$ZDOTS_SNAPSHOT_DIR"/demo/*.txt)" = "partial" ]
}

@test "snapshot: path-unsafe name is refused" {
  run "$SNAP" "../evil" -- echo x
  [ "$status" -eq 1 ]
  [ ! -e "$BATS_TEST_TMPDIR/evil" ]
}

@test "snapshot: --help is inert; captured command's --help is not swallowed" {
  run "$SNAP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  run "$SNAP" demo -- echo --help
  [ "$status" -eq 0 ]
  [ "$(cat "$ZDOTS_SNAPSHOT_DIR"/demo/*.txt)" = "--help" ]
}

@test "snapshot: list and show" {
  "$SNAP" demo -- echo x
  run "$SNAP" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"demo"*"1 captures"* ]]
  run "$SNAP" show demo
  [ "$status" -eq 0 ]
  [[ "$output" == *".txt"* ]]
}
