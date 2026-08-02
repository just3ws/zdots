#!/usr/bin/env bats
# tests/update_local_logging.bats — deployment log partitioning contract

setup() {
  load "setup.bash"
  setup_environment
  TMP_LOG_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_LOG_DIR"
}

@test "zdots-update-local: dry-run log includes nested phase and step context" {
  run env \
    ZDOTS_LOG_DIR="$TMP_LOG_DIR" \
    ZDOTS_TRANSCRIPT_TEE=0 \
    "$REPO_ROOT/bin/zdots-update-local" \
      --dry-run \
      --skip-brew \
      --skip-mise \
      --skip-gems \
      --skip-llama \
      --skip-fabric \
      --skip-otel \
      --skip-check

  [ "$status" -eq 0 ]

  log_file="$(ls "$TMP_LOG_DIR"/zdots-update-local-[0-9]*.log | head -n 1)"
  summary_file="${log_file%.log}.summary.md"

  # Phase positions/totals shift whenever a phase is added — assert the
  # numbering SHAPE and the phase/step identity, not hardcoded ordinals
  # (07/12 rotted when the table grew to 14).
  grep -Eq '==> zdots-update-local phase [0-9]+/[0-9]+: pi: reconcile local llama.cpp model config' "$log_file"
  grep -Eq -- '--> zdots-update-local step [0-9]+\.01: locate pi CLI' "$log_file"
  grep -Eq -- '--> zdots-update-local step [0-9]+\.01: emit log handoff' "$log_file"
  grep -q 'phase=pi: reconcile local llama.cpp model config step=' "$log_file"

  grep -Eq -- '- phase [0-9]+/[0-9]+: pi: reconcile local llama.cpp model config' "$summary_file"
  grep -Eq -- '  - step [0-9]+\.1: locate pi CLI' "$summary_file"
  grep -Eq -- '  - step [0-9]+\.1: emit log handoff' "$summary_file"
}
