#!/usr/bin/env bats
# tests/yard_docs.bats — YARD documentation coverage of lib/ never drops below
# the recorded floor (docs/generated/yard-coverage-baseline.txt).

setup() {
  load "setup.bash"
  setup_environment
  # The Gemfile declares yard, so a host that can't load it fails here rather
  # than skipping: a skipped gate reads as green and is never applied.
  BUNDLE_GEMFILE="$REPO_ROOT/Gemfile" bundle exec yard --version >/dev/null 2>&1 || {
    echo "yard can't be loaded through Bundler: run 'bundle install' in $REPO_ROOT" >&2
    return 1
  }
}

@test "YARD coverage of lib/ is at or above the recorded floor" {
  cd "$REPO_ROOT"
  run env BUNDLE_GEMFILE="$REPO_ROOT/Gemfile" bundle exec yard stats
  [ "$status" -eq 0 ]
  pct="$(printf '%s\n' "$output" | sed -n 's/^ *\([0-9.]*\)% documented.*/\1/p' | tail -1)"
  floor="$(grep -v '^#' docs/generated/yard-coverage-baseline.txt | head -1)"
  [ -n "$pct" ]
  awk -v p="$pct" -v f="$floor" 'BEGIN { exit !(p + 0 >= f + 0) }' || {
    echo "YARD coverage ${pct}% is below the floor ${floor}%" >&2
    return 1
  }
}
