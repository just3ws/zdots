#!/usr/bin/env bats
# tests/typecheck.bats — RBS stays valid, the seam contracts pass under RBS
# runtime checks, and the share of lib/ classes and modules declared in sig/
# never drops below the recorded floor (docs/generated/rbs-coverage-baseline.txt).
# GitHub CI is a sanity check only; this runs in `make check` and zdots-watch.

setup() {
  load "setup.bash"
  setup_environment
  # The Gemfile declares rbs, so a host that can't load it fails here rather
  # than skipping: a skipped gate reads as green and is never applied.
  BUNDLE_GEMFILE="$REPO_ROOT/Gemfile" bundle exec rbs --version >/dev/null 2>&1 || {
    echo "rbs can't be loaded through Bundler: run 'bundle install' in $REPO_ROOT" >&2
    return 1
  }
}

@test "zdots-typecheck: RBS validates and the contracts pass under RBS runtime checks" {
  run "$REPO_ROOT/libexec/zdots-typecheck"
  [ "$status" -eq 0 ]
}

@test "zdots-typecheck --coverage reports declared/defined and the gaps" {
  run "$REPO_ROOT/libexec/zdots-typecheck" --coverage
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ ^rbs\ coverage:\ [0-9]+/[0-9]+\ \([0-9.]+%\)$ ]]
  [[ "$output" == *"missing: Zdots::"* ]]
}

@test "RBS coverage of lib/ is at or above the recorded floor" {
  run "$REPO_ROOT/libexec/zdots-typecheck" --coverage
  pct="$(sed -n 's/^rbs coverage: .*(\([0-9.]*\)%)$/\1/p' <<<"${lines[0]}")"
  floor="$(grep -v '^#' "$REPO_ROOT/docs/generated/rbs-coverage-baseline.txt" | head -1)"
  [ -n "$pct" ]
  awk -v p="$pct" -v f="$floor" 'BEGIN { exit !(p + 0 >= f + 0) }' || {
    echo "RBS coverage ${pct}% is below the floor ${floor}%" >&2
    return 1
  }
}
