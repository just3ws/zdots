#!/usr/bin/env bats
# tests/brewfile_selection.bats — `bin/check` and `zdots-update-local` judge the
# same Brewfile the same way: a machine-local HOMEBREW_BUNDLE_FILE wins over the
# repo's Brewfile.<context>, and a work host never counts outdated packages
# (it never upgrades them).

setup() {
  load "setup.bash"
  setup_environment
  # shellcheck source=lib/brewfile.bash
  . "$REPO_ROOT/lib/brewfile.bash"
  unset HOMEBREW_BUNDLE_FILE ZDOTS_CONTEXT
}

@test "home host uses Brewfile.home and allows upgrades" {
  [ "$(zdots_brewfile "$REPO_ROOT")" = "$REPO_ROOT/Brewfile.home" ]
  [ -z "$(zdots_brew_bundle_flags)" ]
}

@test "work host uses Brewfile.work and never upgrades" {
  ZDOTS_CONTEXT=work
  [ "$(zdots_brewfile "$REPO_ROOT")" = "$REPO_ROOT/Brewfile.work" ]
  [ "$(zdots_brew_bundle_flags)" = "--no-upgrade" ]
}

@test "a machine-local HOMEBREW_BUNDLE_FILE wins" {
  ZDOTS_CONTEXT=work
  HOMEBREW_BUNDLE_FILE=/tmp/curated/Brewfile
  [ "$(zdots_brewfile "$REPO_ROOT")" = "/tmp/curated/Brewfile" ]
}

@test "HOMEBREW_BUNDLE_FILE pointing at a repo Brewfile keeps the context's file" {
  ZDOTS_CONTEXT=work
  HOMEBREW_BUNDLE_FILE="$REPO_ROOT/Brewfile.home"
  [ "$(zdots_brewfile "$REPO_ROOT")" = "$REPO_ROOT/Brewfile.work" ]
}

@test "bin/check and zdots-update-local both select through lib/brewfile.bash" {
  grep -q 'zdots_brewfile' "$REPO_ROOT/bin/check"
  grep -q 'zdots_brew_bundle_flags' "$REPO_ROOT/bin/check"
  grep -q 'zdots_brewfile' "$REPO_ROOT/bin/zdots-update-local"
}
