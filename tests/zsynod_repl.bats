#!/usr/bin/env bats
# zsynod repl — the hybrid follow-along cockpit. The loop itself needs a TTY, so
# here we cover the contracts it stands on: the non-TTY guard, the shared
# _blocking_items list (cmd_minutes and the repl must read the SAME list), and
# the structured asks that let the repl enact a pi-suggested proposal/handoff
# without eval'ing model output.

setup() {
  export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  TMP="$(mktemp -d)"
  export ZSYNOD_DIR="$TMP/zsynod"
  export ZDOTDIR="$REPO_ROOT"
  export ZSYNOD_DISPATCH=0   # no live model in tests
  "$REPO_ROOT/bin/zsynod" init >/dev/null 2>&1
}

teardown() { rm -rf "$TMP"; }

@test "repl refuses to run without an interactive terminal" {
  run bash -c "echo '' | '$REPO_ROOT/bin/zsynod' repl"
  [ "$status" -ne 0 ]
  [[ "$output" == *"interactive terminal"* ]]
}

@test "tick --json carries a structured asks_struct array" {
  run "$REPO_ROOT/bin/zsynod" tick --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'has("asks_struct")'
  echo "$output" | jq -e '.asks_struct | type == "array"'
}

@test "an open proposal shows up as a blocking item in the minutes" {
  "$REPO_ROOT/bin/zsynod" --as claude propose "REPL test proposal" --body x >/dev/null 2>&1
  "$REPO_ROOT/bin/zsynod" minutes >/dev/null 2>&1
  run grep -F "REPL test proposal" "$ZSYNOD_DIR/minutes.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Awaiting"* ]] || grep -q "decide" "$ZSYNOD_DIR/minutes.md"
}

@test "an open question shows up as a blocking item in the minutes" {
  "$REPO_ROOT/bin/zsynod" --as mike ask "Blocking question?" >/dev/null 2>&1
  "$REPO_ROOT/bin/zsynod" minutes >/dev/null 2>&1
  run grep -F "Blocking question?" "$ZSYNOD_DIR/minutes.md"
  [ "$status" -eq 0 ]
}

@test "committed proposals are NOT listed as blocking" {
  "$REPO_ROOT/bin/zsynod" --as claude propose "To be ratified" --body x >/dev/null 2>&1
  "$REPO_ROOT/bin/zsynod" --as mike ratify P1 >/dev/null 2>&1
  "$REPO_ROOT/bin/zsynod" minutes >/dev/null 2>&1
  run sed -n '/## Awaiting you/,/## Backlog/p' "$ZSYNOD_DIR/minutes.md"
  [[ "$output" != *"To be ratified"* ]]
}
