#!/usr/bin/env bats
# tests/ack.bats — tests for ack and fzf shell helpers in conf.d/78-ack.zsh

setup() {
  load "setup.bash"
  setup_environment
}

@test "ack: conf.d/78-ack.zsh passes zsh syntax check" {
  run zsh -n "$REPO_ROOT/conf.d/78-ack.zsh"
  [ "$status" -eq 0 ]
}

@test "ack: conf.d/78-ack.zsh defines fack, fackf, acke, and ack-types" {
  run zsh -c "source '$REPO_ROOT/conf.d/78-ack.zsh' && typeset -f fack fackf acke ack-types"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fack ()"* ]]
  [[ "$output" == *"fackf ()"* ]]
  [[ "$output" == *"acke ()"* ]]
  [[ "$output" == *"ack-types ()"* ]]
}

@test "ack: ack-types runs and lists known types" {
  command -v ack >/dev/null 2>&1 || skip "ack not installed"
  run zsh -c "source '$REPO_ROOT/conf.d/78-ack.zsh' && ack-types"
  [ "$status" -eq 0 ]
  [[ "$output" == *"The following is the list of filetypes supported by ack"* ]]
}
