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
  
  if [ -f "$brew_prefix/lib/bats-support/load.bash" ]; then
    load "$brew_prefix/lib/bats-support/load.bash"
    load "$brew_prefix/lib/bats-assert/load.bash"
    load "$brew_prefix/lib/bats-file/load.bash"
  fi
}
