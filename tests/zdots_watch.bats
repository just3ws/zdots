#!/usr/bin/env bats
# tests/zdots_watch.bats — detector state machine (Z-268/281/284)

setup() {
  load "setup.bash"
  setup_environment
  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  STUB="$BATS_TEST_TMPDIR/stub"
  W="$REPO_ROOT/bin/zdots-watch"
  CHECK_STATE="$XDG_STATE_HOME/zsh/zdots-watch-check.state"
}

_stub() { printf '#!/bin/bash\n%s\n' "$1" >"$STUB"; chmod +x "$STUB"; }

@test "run-check: GREEN seed writes the state file (empty-ids atomic write)" {
  # Regression: the write group ended with a bare [[ -n ids ]] && printf, so a
  # green run exited the group nonzero and the mv never fired — state file
  # missing after a successful seed (bit twice on 2026-08-02).
  _stub 'echo "ok 1 fine"; echo "check: OK"'
  run env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check
  [ "$status" -eq 0 ]
  [ -f "$CHECK_STATE" ]
  grep -q '^rc=0' "$CHECK_STATE"
}

@test "run-check: failing seed writes state with fail identities, no notify" {
  _stub 'echo "not ok 3 thing: broke"; exit 1'
  run env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"seeded"* ]]
  grep -q '^fail|thing: broke' "$CHECK_STATE"
}

@test "run-check: renumbered same-name failure is steady, new name worsens" {
  _stub 'echo "not ok 3 thing: broke"; exit 1'
  env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check >/dev/null
  _stub 'echo "not ok 99 thing: broke"; exit 1'
  run env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check
  [[ "$output" == *"no new failures"* ]]
  _stub 'echo "not ok 1 thing: broke"; echo "not ok 2 other: new"; exit 1'
  run env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check
  [[ "$output" == *"worsened"* ]]
  [[ "$output" == *"other: new"* ]]
}

@test "run-check: recovery is silent and clears identities from state" {
  _stub 'echo "not ok 3 thing: broke"; exit 1'
  env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check >/dev/null
  _stub 'echo "ok 1 fine"; echo "check: OK"'
  run env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check
  [[ "$output" == *"no new failures"* ]]
  ! grep -q '^fail|' "$CHECK_STATE"
  grep -q '^rc=0' "$CHECK_STATE"
}

@test "run-check: evidence persisted and pruned to KEEP" {
  _stub 'echo "ok 1 fine"'
  for _ in 1 2 3 4; do env ZDOTS_WATCH_KEEP=2 ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check >/dev/null; done
  n="$(ls "$XDG_STATE_HOME"/zsh/zdots-watch-runs/check-*.log | wc -l | tr -d ' ')"
  [ "$n" -eq 2 ]
}

@test "run-check: orphaned state tmp from a killed run is cleaned" {
  mkdir -p "$XDG_STATE_HOME/zsh"
  touch "$CHECK_STATE.tmp.99999"
  _stub 'echo "ok 1 fine"'
  env ZDOTS_WATCH_CHECK_CMD="$STUB" "$W" run-check >/dev/null
  [ ! -e "$CHECK_STATE.tmp.99999" ]
}
