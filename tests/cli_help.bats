#!/usr/bin/env bats
# tests/cli_help.bats — unit contract for lib/cli-help.bash predicates.
#
# WHAT: zdots_cli_wants_help / _strict are the single source of truth for
# "do these args request help?", extracted from the ~10 inline Z-182 guards.
# WHY: flag_audit.bats proves the end-to-end --help-inert contract per command;
# this proves the shared predicate those guards now delegate to, in isolation,
# including the position-agnostic and strict (bare-value passthrough) semantics.

setup() {
  load "setup.bash"
  setup_environment
  source "$REPO_ROOT/lib/cli-help.bash"
}

@test "wants_help: true for -h / --help in any position" {
  run zdots_cli_wants_help --help;            [ "$status" -eq 0 ]
  run zdots_cli_wants_help -h;                 [ "$status" -eq 0 ]
  run zdots_cli_wants_help sub --help;         [ "$status" -eq 0 ]
  run zdots_cli_wants_help sub arg -h;         [ "$status" -eq 0 ]
}

@test "wants_help: false for no help flag, bare values, or empty" {
  run zdots_cli_wants_help;                    [ "$status" -eq 1 ]
  run zdots_cli_wants_help "";                 [ "$status" -eq 1 ]
  run zdots_cli_wants_help file.wav;           [ "$status" -eq 1 ]
  run zdots_cli_wants_help --json status;      [ "$status" -eq 1 ]
}

@test "wants_help_strict: true for -h/--help or any leading flag before --" {
  run zdots_cli_wants_help_strict --help;      [ "$status" -eq 0 ]
  run zdots_cli_wants_help_strict -h;          [ "$status" -eq 0 ]
  run zdots_cli_wants_help_strict --bogus;     [ "$status" -eq 0 ]
  run zdots_cli_wants_help_strict -x file;     [ "$status" -eq 0 ]
}

@test "wants_help_strict: bare values pass through; -- terminates flag scan" {
  run zdots_cli_wants_help_strict file.wav;    [ "$status" -eq 1 ]
  run zdots_cli_wants_help_strict;             [ "$status" -eq 1 ]
  run zdots_cli_wants_help_strict -- --help;   [ "$status" -eq 1 ]
}
