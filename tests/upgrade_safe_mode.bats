#!/usr/bin/env bats
# tests/upgrade_safe_mode.bats — `upgrade` picks its mode from the host: safe on
# a work host (ZDOTS_CONTEXT=work, set by the adots work profile), full
# elsewhere; `--safe` and `--full` override. Safe mode stays inside what zdots
# owns and deletes nothing: no OS updates, no downloaded installer rewriting
# shell startup files, no pruning of old kegs, runtimes or models. Formulae the
# machine holds (ZDOTS_UPGRADE_HOLD) are left alone in every mode.

setup() {
  load "setup.bash"
  setup_environment
  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  # A brew that reports four outdated packages, has something missing from the
  # Brewfile, and records what it's asked.
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
  unset ZDOTS_CONTEXT ZDOTS_UPGRADE_MODE ZDOTS_UPGRADE_HOLD ZDOTS_UPGRADE_DRY_RUN ZDOTS_HOMEBREW_AGGRESSIVE HOMEBREW_BUNDLE_FILE
}

# Runs `upgrade "$@"` with every module stubbed to print its name and mode.
orchestrate() {
  run zsh -fc '
    fpath=("$ZDOTDIR/functions/enabled" $fpath); autoload -Uz upgrade upgrade-mode run_cmd
    for m in upgrade-homebrew upgrade-macos upgrade-mise upgrade-rust upgrade-node upgrade-ai upgrade-iterm upgrade-repo; do
      functions[$m]="print -r -- ran:$m mode:\${ZDOTS_UPGRADE_MODE:-unset}"
    done
    upgrade "$@"' upgrade "$@"
}

# Runs one module on its own, as `upgrade-homebrew` typed at the prompt would.
module() {
  local m="$1"; shift
  run env PATH="$STUBS:/usr/bin:/bin" "$@" zsh -fc 'fpath=("$ZDOTDIR/functions/enabled" $fpath); autoload -Uz run_cmd cleanup-homebrew upgrade-mode '"$m"'; '"$m"
}

# bats ignores a bare `! cmd` unless it's a test's last line.
never() { if grep -qE "$1" "$BATS_TEST_TMPDIR/$2.calls"; then echo "unexpected: $1"; return 1; fi; }

@test "a work host defaults to safe mode: no OS updates, no iTerm installer" {
  ZDOTS_CONTEXT=work orchestrate
  [ "$status" -eq 0 ]
  [[ "$output" == *"ran:upgrade-homebrew mode:safe"* ]]
  [[ "$output" == *"ran:upgrade-mise mode:safe"* ]]
  [[ "$output" != *"ran:upgrade-macos"* ]]
  [[ "$output" != *"ran:upgrade-iterm"* ]]
}

@test "safe mode elsewhere says how to run what it skipped" {
  orchestrate --safe
  [[ "$output" == *"upgrade --full"* ]]
}

@test "any other host defaults to full mode and runs every module" {
  orchestrate
  [ "$status" -eq 0 ]
  [[ "$output" == *"ran:upgrade-macos mode:full"* ]]
  [[ "$output" == *"ran:upgrade-iterm mode:full"* ]]
}

@test "--full and --safe override the host's default" {
  ZDOTS_CONTEXT=work orchestrate --full
  [[ "$output" == *"ran:upgrade-homebrew mode:full"* ]]
  orchestrate --safe
  [[ "$output" == *"ran:upgrade-homebrew mode:safe"* ]]
  [[ "$output" != *"ran:upgrade-macos"* ]]
}

@test "a work host never runs OS updates or the iTerm installer, even with --full" {
  # The OS belongs to the employer's device management, and the installer
  # appends to ~/.zshrc, which the employer's setup owns.
  ZDOTS_CONTEXT=work orchestrate --full
  [ "$status" -eq 0 ]
  [[ "$output" != *"ran:upgrade-macos"* ]]
  [[ "$output" != *"ran:upgrade-iterm"* ]]
  [[ "$output" == *"work host"* ]]
}

@test "the mode doesn't leak into the calling shell" {
  run zsh -fc '
    fpath=("$ZDOTDIR/functions/enabled" $fpath); autoload -Uz upgrade upgrade-mode run_cmd
    for m in upgrade-homebrew upgrade-macos upgrade-mise upgrade-rust upgrade-node upgrade-ai upgrade-iterm upgrade-repo; do functions[$m]=:; done
    upgrade >/dev/null; print -r -- "after:${ZDOTS_UPGRADE_MODE:-unset}"'
  [[ "$output" == "after:unset" ]]
}

@test "safe homebrew upgrades everything outdated except the held formulae, by name or tap name" {
  module upgrade-homebrew ZDOTS_CONTEXT=work ZDOTS_UPGRADE_HOLD="postgresql@17 colima"
  [ "$status" -eq 0 ]
  grep -qx 'brew upgrade --verbose gh marked-app' "$BATS_TEST_TMPDIR/brew.calls"
  never '^brew upgrade --verbose$' brew
  # Reconciling the Brewfile mustn't upgrade a held formula behind our back.
  grep -q '^brew bundle --file' "$BATS_TEST_TMPDIR/brew.calls"
  never '^brew bundle --file [^ ]*$' brew
  never '^brew cleanup' brew
}

@test "full homebrew still leaves held formulae alone, then cleans up" {
  module upgrade-homebrew ZDOTS_CONTEXT=work ZDOTS_UPGRADE_MODE=full ZDOTS_UPGRADE_HOLD="postgresql@17 colima"
  [ "$status" -eq 0 ]
  grep -qx 'brew upgrade --verbose gh marked-app' "$BATS_TEST_TMPDIR/brew.calls"
  never '^brew bundle --file [^ ]*$' brew
  grep -q '^brew cleanup' "$BATS_TEST_TMPDIR/brew.calls"
}

@test "full homebrew with nothing held upgrades everything" {
  module upgrade-homebrew
  [ "$status" -eq 0 ]
  grep -qx 'brew upgrade --verbose' "$BATS_TEST_TMPDIR/brew.calls"
}

@test "mise run on its own follows the host: a work host keeps old runtimes, others prune" {
  module upgrade-mise ZDOTS_CONTEXT=work
  [ "$status" -eq 0 ]
  grep -qx 'mise install' "$BATS_TEST_TMPDIR/mise.calls"
  never 'prune' mise
  rm "$BATS_TEST_TMPDIR/mise.calls"
  module upgrade-mise
  grep -qx 'mise prune --yes' "$BATS_TEST_TMPDIR/mise.calls"
}
