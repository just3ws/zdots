#!/usr/bin/env bats
# tests/upgrade_safe_mode.bats — `upgrade` runs in safe mode unless asked for
# `--full`. Safe mode stays inside what zdots owns: no OS updates, no downloaded
# installer rewriting shell startup files, no upgrade of formulae the machine
# holds (ZDOTS_UPGRADE_HOLD, set machine-locally), and no pruning of runtimes
# something else may still use.

setup() {
  load "setup.bash"
  setup_environment
  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  # A brew that reports three outdated packages and records what it's asked.
  cat >"$STUBS/brew" <<'EOF'
#!/bin/sh
echo "brew $*" >>"$BATS_TEST_TMPDIR/brew.calls"
case "$1" in
  bundle) [ "$2" = check ] && exit 1 ;;
  outdated) printf 'gh\npostgresql@17\nhomebrew/core/colima\nmarked-app\n' ;;
esac
exit 0
EOF
  cat >"$STUBS/mise" <<'EOF'
#!/bin/sh
echo "mise $*" >>"$BATS_TEST_TMPDIR/mise.calls"
exit 0
EOF
  chmod +x "$STUBS/brew" "$STUBS/mise"
  export BATS_TEST_TMPDIR
  export ZDOTS_LOG_DIR="$BATS_TEST_TMPDIR/logs"
  unset ZDOTS_UPGRADE_MODE ZDOTS_UPGRADE_DRY_RUN ZDOTS_HOMEBREW_AGGRESSIVE HOMEBREW_BUNDLE_FILE
}

# Runs `upgrade "$@"` with every module stubbed to print its name.
orchestrate() {
  run zsh -fc '
    fpath=("$ZDOTDIR/functions/enabled" $fpath); autoload -Uz upgrade run_cmd
    for m in upgrade-homebrew upgrade-macos upgrade-mise upgrade-rust upgrade-node upgrade-ai upgrade-iterm upgrade-repo; do
      functions[$m]="print -r -- ran:$m mode:\${ZDOTS_UPGRADE_MODE:-unset}"
    done
    upgrade "$@"' upgrade "$@"
}

module() {
  local m="$1"; shift
  run env PATH="$STUBS:/usr/bin:/bin" "$@" zsh -fc 'fpath=("$ZDOTDIR/functions/enabled" $fpath); autoload -Uz run_cmd cleanup-homebrew '"$m"'; '"$m"
}

# bats ignores a bare `! cmd` unless it's a test's last line.
never() { if grep -qE "$1" "$BATS_TEST_TMPDIR/$2.calls"; then echo "unexpected: $1"; return 1; fi; }

@test "upgrade defaults to safe mode: no OS updates, no iTerm installer" {
  orchestrate
  [ "$status" -eq 0 ]
  [[ "$output" == *"ran:upgrade-homebrew mode:safe"* ]]
  [[ "$output" == *"ran:upgrade-mise mode:safe"* ]]
  [[ "$output" != *"ran:upgrade-macos"* ]]
  [[ "$output" != *"ran:upgrade-iterm"* ]]
  [[ "$output" == *"upgrade --full"* ]]
}

@test "upgrade --full runs every module" {
  orchestrate --full
  [ "$status" -eq 0 ]
  [[ "$output" == *"ran:upgrade-macos mode:full"* ]]
  [[ "$output" == *"ran:upgrade-iterm mode:full"* ]]
}

@test "the mode doesn't leak into the calling shell" {
  run zsh -fc '
    fpath=("$ZDOTDIR/functions/enabled" $fpath); autoload -Uz upgrade run_cmd
    for m in upgrade-homebrew upgrade-macos upgrade-mise upgrade-rust upgrade-node upgrade-ai upgrade-iterm upgrade-repo; do functions[$m]=:; done
    upgrade >/dev/null; print -r -- "after:${ZDOTS_UPGRADE_MODE:-unset}"'
  [[ "$output" == "after:unset" ]]
}

@test "safe homebrew upgrades everything outdated except the held formulae, by name or tap name" {
  module upgrade-homebrew ZDOTS_UPGRADE_HOLD="postgresql@17 colima"
  [ "$status" -eq 0 ]
  grep -qx 'brew upgrade --verbose gh marked-app' "$BATS_TEST_TMPDIR/brew.calls"
  never '^brew upgrade --verbose$' brew
  # Reconciling the Brewfile mustn't upgrade a held formula behind our back.
  grep -q '^brew bundle --file' "$BATS_TEST_TMPDIR/brew.calls"
  never '^brew bundle --file [^ ]*$' brew
}

@test "full homebrew upgrades everything" {
  module upgrade-homebrew ZDOTS_UPGRADE_HOLD="postgresql@17 colima" ZDOTS_UPGRADE_MODE=full
  [ "$status" -eq 0 ]
  grep -qx 'brew upgrade --verbose' "$BATS_TEST_TMPDIR/brew.calls"
}

@test "safe mise keeps old runtimes; full prunes them" {
  module upgrade-mise
  [ "$status" -eq 0 ]
  grep -qx 'mise install' "$BATS_TEST_TMPDIR/mise.calls"
  never 'prune' mise
  rm "$BATS_TEST_TMPDIR/mise.calls"
  module upgrade-mise ZDOTS_UPGRADE_MODE=full
  grep -qx 'mise prune --yes' "$BATS_TEST_TMPDIR/mise.calls"
}
