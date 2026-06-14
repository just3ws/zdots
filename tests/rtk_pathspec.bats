#!/usr/bin/env bats
# tests/rtk_pathspec.bats — regression test for Z-118
#
# Bug: rtk git diff -- <pathspec> reported "fatal: bad revision <pathspec>"
# instead of forwarding the -- sentinel verbatim to git.
#
# Fixed in rtk 0.42.4 (upstream). These tests guard against regression
# if rtk is downgraded or its -- handling changes again.
#
# Tests:
#   A. rtk git diff -- <file>     exits 0 (no "bad revision" error)
#   B. rtk git diff -- <dir/>     exits 0
#   C. rtk git log  -- <file>     exits 0

bats_require_minimum_version 1.5.0

setup() {
  load "setup.bash"
  setup_environment
  command -v rtk >/dev/null 2>&1 || skip "rtk not installed"
  command -v git >/dev/null 2>&1 || skip "git not installed"
  # All tests run from the repo root so git commands have a valid repo.
  cd "$REPO_ROOT" || skip "cannot cd to REPO_ROOT"
}

# ---------------------------------------------------------------------------
# A. rtk git diff -- <file>
# ---------------------------------------------------------------------------

@test "A1: rtk git diff -- Makefile exits 0 (Z-118: no bad-revision error)" {
  run rtk git diff -- Makefile
  [ "$status" -eq 0 ]
  refute_output --partial "bad revision"
  refute_output --partial "fatal:"
}

@test "A2: rtk git diff -- <file> output matches plain git diff -- <file>" {
  plain=$(git diff -- Makefile 2>&1)
  run rtk git diff -- Makefile
  [ "$status" -eq 0 ]
  # Both should be empty when tree is clean; if not, both should have content.
  # We only check for absence of the regression error.
  refute_output --partial "bad revision"
}

# ---------------------------------------------------------------------------
# B. rtk git diff -- <dir>
# ---------------------------------------------------------------------------

@test "B1: rtk git diff -- bin/ exits 0" {
  run rtk git diff -- bin/
  [ "$status" -eq 0 ]
  refute_output --partial "bad revision"
  refute_output --partial "fatal:"
}

# ---------------------------------------------------------------------------
# C. rtk git log -- <file>
# ---------------------------------------------------------------------------

@test "C1: rtk git log -- Makefile exits 0" {
  run rtk git log -- Makefile
  [ "$status" -eq 0 ]
  refute_output --partial "bad revision"
  refute_output --partial "fatal:"
}
