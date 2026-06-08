#!/usr/bin/env bash
# tests/setup.bash — Setup helper for Bats tests

setup_environment() {
  # Root of the repository
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  export REPO_ROOT
  export ZDOTDIR="$REPO_ROOT"
  
  # Load Bats helpers if they are installed in standard Homebrew paths
  # (Fallback to assuming they are in the PATH if not found in /opt/homebrew)
  local brew_prefix="${HOMEBREW_PREFIX:-/opt/homebrew}"
  
  # Load Bats helpers — prioritize local tests/helpers for CI stability
  if [ -f "$REPO_ROOT/tests/helpers/bats-support/load.bash" ]; then
    load "$REPO_ROOT/tests/helpers/bats-support/load.bash"
    load "$REPO_ROOT/tests/helpers/bats-assert/load.bash"
    load "$REPO_ROOT/tests/helpers/bats-file/load.bash"
  elif [ -f "$brew_prefix/lib/bats-support/load.bash" ]; then
    load "$brew_prefix/lib/bats-support/load.bash"
    load "$brew_prefix/lib/bats-assert/load.bash"
    load "$brew_prefix/lib/bats-file/load.bash"
  fi

  # Load keychain helpers
  source "$REPO_ROOT/lib/keychain.bash"
}

# skip_in_ci — quarantine environment-dependent tests from automated CI.
# These need live services, launchd state, or a provisioned machine, so they are
# meant to run on the LOCAL pipeline step (bin/check / make check, where $CI is
# unset). In GitHub Actions ($CI=true) — or any run with ZDOTS_SKIP_ENV_TESTS=1 —
# they skip instead of failing. Call as the first line of such a @test.
skip_in_ci() {
  if [[ -n "${CI:-}" || "${ZDOTS_SKIP_ENV_TESTS:-0}" == "1" ]]; then
    skip "environment-dependent — run on the local pipeline step (make check); skipped in CI"
  fi
}
