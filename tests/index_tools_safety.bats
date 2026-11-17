#!/usr/bin/env bats
# tests/index_tools_safety.bats — building the command catalog must not run
# commands for real. zdots-index-tools calls every bin/ command with --help;
# commands documented as unsafe to call that way (docs-contract known gaps)
# are skipped, and colima-autostart answers --help without starting Colima.

setup() {
  load "setup.bash"
  setup_environment
  FAKE="$BATS_TEST_TMPDIR/zdots"
  MARK="$BATS_TEST_TMPDIR/ran"
  mkdir -p "$FAKE/bin" "$FAKE/docs/generated" "$BATS_TEST_TMPDIR/stubs" "$BATS_TEST_TMPDIR/state"
  cp "$REPO_ROOT/bin/zdots-index-tools" "$FAKE/bin/"
  # A command with a side effect whenever it runs, documented as a known gap.
  printf '#!/bin/sh\necho "$*" >>"%s"\necho "did a thing"\n' "$MARK" >"$FAKE/bin/sidefx"
  # A well-behaved command.
  printf '#!/bin/sh\necho "Usage: fine"\n' >"$FAKE/bin/fine"
  chmod +x "$FAKE/bin/"*
  printf '# known gaps\nsidefx: starts something on invocation; no --help contract z-119\n' \
    >"$FAKE/docs/generated/docs-contract-known-gaps.txt"
  printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/stubs/zdots-ctx"
  chmod +x "$BATS_TEST_TMPDIR/stubs/zdots-ctx"
}

@test "zdots-index-tools never runs a known-gap command" {
  ZDOTDIR="$FAKE" XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" PATH="$BATS_TEST_TMPDIR/stubs:$PATH" \
    run "$FAKE/bin/zdots-index-tools" --dry-run --force
  [ "$status" -eq 0 ]
  [ ! -e "$MARK" ]
  [[ "$output" == *"sidefx"* ]]
  [[ "$output" == *"fine"* ]]
}

@test "colima-autostart --help prints usage and starts nothing" {
  run env XDG_STATE_HOME="$BATS_TEST_TMPDIR/state" "$REPO_ROOT/bin/colima-autostart" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  # The real run logs "begin" before touching Colima; --help must stop first.
  [ ! -e "$BATS_TEST_TMPDIR/state/zsh/colima-autostart.log" ]
}
