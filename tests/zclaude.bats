#!/usr/bin/env bats
# tests/zclaude.bats — zclaude launcher config resolution (via --dry-run).
# These assert the resolved `claude` invocation; they never launch a session.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  BIN="$REPO_ROOT/bin/zclaude"
  export ZDOTDIR="$REPO_ROOT"
}

@test "zclaude: --help exits 0 and documents the modes" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--sync"* ]]
  [[ "$output" == *"--auto"* ]]
  [[ "$output" == *"--feature"* ]]
}

@test "zclaude: default interactive mode resolves to sonnet" {
  run "$BIN" --dry-run "do a thing"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=interactive model=sonnet"* ]]
  [[ "$output" == *"--model sonnet"* ]]
}

@test "zclaude: --auto resolves to haiku and uses --print" {
  run "$BIN" --auto "report drift" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=auto model=haiku"* ]]
  [[ "$output" == *"--print"* ]]
}

@test "zclaude: --feature resolves to opus with plan permission mode" {
  run "$BIN" --feature --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=feature model=opus"* ]]
  [[ "$output" == *"--permission-mode plan"* ]]
}

@test "zclaude: --sync is headless and read-only (no commit/push in the task)" {
  run "$BIN" --sync --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=sync"* ]]
  [[ "$output" == *"--print"* ]]
  # dry-run escapes spaces (printf %q); match unspaced tokens from the canned task
  [[ "$output" == *"platform-sync"* ]]
  [[ "$output" == *"commit"* ]]
  [[ "$output" == *"push"* ]]
}

@test "zclaude: --model overrides the per-mode default" {
  run "$BIN" --model opus --dry-run "x"
  [ "$status" -eq 0 ]
  [[ "$output" == *"model=opus"* ]]
}

@test "zclaude: --add-dir precedes --append-system-prompt so the prompt is not swallowed" {
  run "$BIN" --dry-run "the task"
  [ "$status" -eq 0 ]
  # Order must be: --add-dir ... --append-system-prompt ... <prompt>, so the
  # variadic --add-dir cannot swallow the trailing prompt ("task" survives %q).
  [[ "$output" == *"--add-dir"*"--append-system-prompt"*"task"* ]]
}

@test "zclaude: --auto with no task is a usage error" {
  run "$BIN" --auto --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"needs a task"* ]]
}

@test "zclaude: unknown option is rejected with guidance" {
  run "$BIN" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}
