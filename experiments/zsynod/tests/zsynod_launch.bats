#!/usr/bin/env bats
# zsynod launch — live facilitator launcher. Dispatch is disabled so tests
# validate prompt/session wiring without invoking frontier CLIs.

setup() {
  export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  export ZSYNOD_DIR="$BATS_TEST_TMPDIR/zsynod"
  export ZDOTDIR="$REPO_ROOT"
  export ZSYNOD_DISPATCH=0
  "$REPO_ROOT/bin/zsynod" init >/dev/null
}

@test "launch requires explicit frontier facilitator" {
  run "$REPO_ROOT/bin/zsynod" launch --ticks 2

  [ "$status" -ne 0 ]
  [[ "$output" == *"launch needs --facilitator"* ]]
}

@test "launch requires positive tick bound" {
  run "$REPO_ROOT/bin/zsynod" launch --facilitator codex --ticks 0

  [ "$status" -ne 0 ]
  [[ "$output" == *"launch needs --ticks N"* ]]
}

@test "launch dry-run records frontier-first facilitation session" {
  "$REPO_ROOT/bin/zsynod" --as mike propose "Durable facilitation" >/dev/null

  run "$REPO_ROOT/bin/zsynod" launch --facilitator codex --ticks 3 --session p15-live --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "zsynod_launch" ]
  [ "$(printf '%s' "$output" | jq -r '.facilitator')" = "codex" ]
  [ "$(printf '%s' "$output" | jq -r '.ticks')" = "3" ]
  [ "$(printf '%s' "$output" | jq -r '.session.id')" = "p15-live" ]
  [ "$(printf '%s' "$output" | jq -r '.session.meeting_type')" = "facilitation" ]
  [ "$(printf '%s' "$output" | jq -r '.session.participants | join(",")')" = "claude,gemini,codex,antigravity" ]
  [ "$(printf '%s' "$output" | jq -r '.harness.cli')" = "codex" ]
  [ "$(printf '%s' "$output" | jq -r '.harness.mode')" = "unsupported-create-name" ]
  [[ "$(printf '%s' "$output" | jq -r '.prompt')" == *"run at most 3 tick-cycle"* ]]
  [[ "$(printf '%s' "$output" | jq -r '.prompt')" == *"zsynod tick --frontier"* ]]
  [ "$(jq -r '.id' "$ZSYNOD_DIR/sessions/p15-live.json")" = "p15-live" ]
  [ "$(jq -r '.meeting_type' "$ZSYNOD_DIR/sessions/p15-live.json")" = "facilitation" ]
  [ "$(jq -r '.participants | join(",")' "$ZSYNOD_DIR/sessions/p15-live.json")" = "claude,gemini,codex,antigravity" ]
  [ "$(jq -r '.harness.codex.mode' "$ZSYNOD_DIR/sessions/p15-live.json")" = "unsupported-create-name" ]
  [ "$(wc -l < "$ZSYNOD_DIR/sessions/p15-live.turns.jsonl" | tr -d ' ')" = "1" ]
  [ "$(wc -l < "$ZSYNOD_DIR/sessions/p15-live.launches.jsonl" | tr -d ' ')" = "1" ]
}

@test "launch rejects local facilitator" {
  run "$REPO_ROOT/bin/zsynod" launch --facilitator pi --ticks 1

  [ "$status" -ne 0 ]
  [[ "$output" == *"facilitator must be a frontier member"* ]]
}

@test "launch resumes named session participants unless overridden" {
  "$REPO_ROOT/bin/zsynod" launch --facilitator codex --ticks 1 --session p15-custom --participants codex,gemini --json >/dev/null

  run "$REPO_ROOT/bin/zsynod" launch --facilitator gemini --ticks 1 --session p15-custom --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.session.participants | join(",")')" = "codex,gemini" ]
  [ "$(jq -r '.turn_count' "$ZSYNOD_DIR/sessions/p15-custom.json")" = "2" ]
}

@test "launch uses Claude named session argument when Claude facilitates" {
  run "$REPO_ROOT/bin/zsynod" launch --facilitator claude --ticks 1 --session p15-claude --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.harness.cli')" = "claude" ]
  [ "$(printf '%s' "$output" | jq -r '.harness.mode')" = "name" ]
  [ "$(printf '%s' "$output" | jq -r '.harness.key')" = "zsynod-p15-claude-claude" ]
  [ "$(printf '%s' "$output" | jq -r '.harness.launch_args | join(" ")')" = "--name zsynod-p15-claude-claude" ]
  [ "$(jq -r '.harness.claude.key' "$ZSYNOD_DIR/sessions/p15-claude.json")" = "zsynod-p15-claude-claude" ]
}

@test "launch uses deterministic Gemini session id when Gemini facilitates" {
  run "$REPO_ROOT/bin/zsynod" launch --facilitator gemini --ticks 1 --session p15-gemini --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.harness.cli')" = "gemini" ]
  [ "$(printf '%s' "$output" | jq -r '.harness.mode')" = "session-id" ]
  [[ "$(printf '%s' "$output" | jq -r '.harness.key')" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}$ ]]
  [ "$(printf '%s' "$output" | jq -r '.harness.launch_args[0]')" = "--session-id" ]
  [ "$(jq -r '.harness.gemini.mode' "$ZSYNOD_DIR/sessions/p15-gemini.json")" = "session-id" ]
}
