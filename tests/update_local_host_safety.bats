#!/usr/bin/env bats
# tests/update_local_host_safety.bats — managed hosts keep `make update-local`
# safe as written: a machine-local skip list, and no Homebrew upgrades on work.
# Every run is --dry-run with a stub brew; nothing is installed or changed.

setup() {
  load "setup.bash"
  setup_environment
  TMP_LOG_DIR="$(mktemp -d)"
  mkdir -p "$TMP_LOG_DIR/bin"
  printf '#!/bin/sh\nexit 0\n' > "$TMP_LOG_DIR/bin/brew"
  chmod +x "$TMP_LOG_DIR/bin/brew"
}

teardown() {
  rm -rf "$TMP_LOG_DIR"
}

# Run a dry run with every phase but brew skipped on the command line, unless
# the test passes its own environment.
run_update() {
  run env PATH="$TMP_LOG_DIR/bin:$PATH" ZDOTS_LOG_DIR="$TMP_LOG_DIR" ZDOTS_TRANSCRIPT_TEE=0 \
    HOMEBREW_BUNDLE_FILE= "$@" "$REPO_ROOT/bin/zdots-update-local" --dry-run
}

log_text() {
  cat "$(ls "$TMP_LOG_DIR"/zdots-update-local-[0-9]*.log | head -n 1)"
}

@test "ZDOTS_UPDATE_LOCAL_SKIP skips the listed phases" {
  run_update ZDOTS_UPDATE_LOCAL_SKIP="brew mise gems python llama fabric pi aider gemini otel index-tools check"
  [ "$status" -eq 0 ]
  out="$(log_text)"
  [[ "$out" == *"skipping brew phase (ZDOTS_UPDATE_LOCAL_SKIP)"* ]]
  [[ "$out" == *"skipping llama phase (ZDOTS_UPDATE_LOCAL_SKIP)"* ]]
  [[ "$out" != *"command=brew bundle"* ]]
  [[ "$out" != *"llama-ctl install"* ]]
}

@test "ZDOTS_UPDATE_LOCAL_SKIP rejects an unknown phase name" {
  run_update ZDOTS_UPDATE_LOCAL_SKIP="brew llamma"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown phase in ZDOTS_UPDATE_LOCAL_SKIP: llamma"* ]]
}

@test "work context runs brew bundle with --no-upgrade" {
  run_update ZDOTS_CONTEXT=work \
    ZDOTS_UPDATE_LOCAL_SKIP="mise gems python llama fabric pi aider gemini otel index-tools check"
  [ "$status" -eq 0 ]
  [[ "$(log_text)" == *"command=brew bundle --no-upgrade --file $REPO_ROOT/Brewfile.work"* ]]
}

@test "home context keeps brew bundle upgrades" {
  run_update ZDOTS_CONTEXT=home \
    ZDOTS_UPDATE_LOCAL_SKIP="mise gems python llama fabric pi aider gemini otel index-tools check"
  [ "$status" -eq 0 ]
  [[ "$(log_text)" == *"command=brew bundle --file $REPO_ROOT/Brewfile.home"* ]]
}
