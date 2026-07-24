#!/usr/bin/env bats
# tests/completions.bats — structural gate for functions/enabled/_* (Z-233).
#
# WHAT: every completion file parses clean and declares its command.
# WHY: the old command-qc gate SOURCED the files, which executes the trailing
# `_<cmd> "$@"` outside compsys — _arguments always errors there and the exit
# code was just whichever statement ran last. Parse-only is the honest signal.

ZDOTS="${BATS_TEST_DIRNAME}/.."

@test "completions: every file parses (zsh -n)" {
  for f in "$ZDOTS"/functions/enabled/_*; do
    run zsh -n "$f"
    [ "$status" -eq 0 ] || { echo "parse failure: $f"; return 1; }
  done
}

@test "completions: every file opens with a #compdef header" {
  for f in "$ZDOTS"/functions/enabled/_*; do
    run head -1 "$f"
    [[ "$output" == "#compdef"* ]] || { echo "missing #compdef: $f"; return 1; }
  done
}
