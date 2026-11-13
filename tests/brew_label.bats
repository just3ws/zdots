#!/usr/bin/env bats
# tests/brew_label.bats — Homebrew launchd label resolution (sh.brew.* since
# Homebrew 7, homebrew.mxcl.* before). Fake agent/daemon dirs; nothing real.

setup() {
  load "setup.bash"
  setup_environment
  export HOME="$BATS_TEST_TMPDIR/home"
  export ZDOTS_LAUNCHD_SYSTEM_DIR="$BATS_TEST_TMPDIR/LaunchDaemons"
  mkdir -p "$HOME/Library/LaunchAgents" "$ZDOTS_LAUNCHD_SYSTEM_DIR"
}

label() {
  run bash -c "source '$REPO_ROOT/lib/brew-label.bash'; zdots_brew_label '$1'"
}

@test "defaults to the current sh.brew prefix when nothing is installed" {
  label nginx
  [ "$status" -eq 0 ]
  [ "$output" = "sh.brew.nginx" ]
}

@test "finds a current user agent" {
  touch "$HOME/Library/LaunchAgents/sh.brew.postgresql@17.plist"
  label postgresql@17
  [ "$output" = "sh.brew.postgresql@17" ]
}

@test "keeps a legacy user agent installed by older Homebrew" {
  touch "$HOME/Library/LaunchAgents/homebrew.mxcl.redis.plist"
  label redis
  [ "$output" = "homebrew.mxcl.redis" ]
}

@test "finds a legacy system daemon (root nginx)" {
  touch "$ZDOTS_LAUNCHD_SYSTEM_DIR/homebrew.mxcl.nginx.plist"
  label nginx
  [ "$output" = "homebrew.mxcl.nginx" ]
}

@test "prefers the current label when both plists exist" {
  touch "$HOME/Library/LaunchAgents/homebrew.mxcl.nginx.plist" \
        "$HOME/Library/LaunchAgents/sh.brew.nginx.plist"
  label nginx
  [ "$output" = "sh.brew.nginx" ]
}

@test "nginx-ctl and nginx-repair resolve the label instead of hardcoding it" {
  ! grep -q 'homebrew.mxcl.nginx"' "$REPO_ROOT/bin/nginx-ctl"
  ! grep -q 'homebrew.mxcl.nginx"' "$REPO_ROOT/bin/nginx-repair"
  grep -q 'zdots_brew_label nginx' "$REPO_ROOT/bin/nginx-ctl"
  grep -q 'zdots_brew_label nginx' "$REPO_ROOT/bin/nginx-repair"
}
