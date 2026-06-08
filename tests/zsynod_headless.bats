#!/usr/bin/env bats

setup() {
  export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  export ZSYNOD_DIR="$BATS_TEST_TMPDIR/zsynod"
  export ZDOTDIR="$REPO_ROOT"
  "$REPO_ROOT/bin/zsynod" init >/dev/null
}

@test "zsynod turn --json emits pipeable ledger report" {
  "$REPO_ROOT/bin/zsynod" --as mike propose "Headless test" --body "exercise report" >/dev/null
  "$REPO_ROOT/bin/zsynod" --as codex vote P1 aye >/dev/null

  run "$REPO_ROOT/bin/zsynod" turn --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "zsynod_turn" ]
  [ "$(printf '%s' "$output" | jq -r '.verify.ok')" = "true" ]
  [ "$(printf '%s' "$output" | jq -r '.proposals[0].id')" = "P1" ]
  [ "$(printf '%s' "$output" | jq -r '.proposals[0].needed')" = "3" ]
  [ "$(printf '%s' "$output" | jq -r '.suggested_actions[0].action')" = "collect_votes" ]
}

@test "zsynod turn --since limits entries_since" {
  "$REPO_ROOT/bin/zsynod" --as mike propose "First" >/dev/null
  "$REPO_ROOT/bin/zsynod" --as codex speak P1 "after proposal" >/dev/null

  run "$REPO_ROOT/bin/zsynod" turn --json --since 1

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.since')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.entries_since | length')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.entries_since[0].type')" = "speak" ]
}

@test "zsynod console --headless delegates to turn report" {
  "$REPO_ROOT/bin/zsynod" --as mike propose "Console report" >/dev/null

  run "$REPO_ROOT/bin/zsynod" console --headless --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.kind')" = "zsynod_turn" ]
  [ "$(printf '%s' "$output" | jq -r '.proposals[0].title')" = "Console report" ]
}

@test "zsynod turn rejects invalid since" {
  run "$REPO_ROOT/bin/zsynod" turn --since nope

  [ "$status" -ne 0 ]
  [[ "$output" == *"--since must be a non-negative integer"* ]]
}

@test "zsynod turn --max-tokens reports constrained output instead of failing" {
  "$REPO_ROOT/bin/zsynod" --as mike propose "Budgeted" >/dev/null
  "$REPO_ROOT/bin/zsynod" --as codex speak P1 "one" >/dev/null
  "$REPO_ROOT/bin/zsynod" --as gemini speak P1 "two" >/dev/null

  run "$REPO_ROOT/bin/zsynod" turn --json --max-tokens 1

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.resource.status')" = "constrained" ]
  [ "$(printf '%s' "$output" | jq -r '.resource.truncated')" = "true" ]
  [ "$(printf '%s' "$output" | jq -r '.entries_since | length')" = "1" ]
}

@test "zsynod turn --session --frontier records named session metadata" {
  "$REPO_ROOT/bin/zsynod" --as mike propose "Frontier topic" >/dev/null

  run "$REPO_ROOT/bin/zsynod" turn --session frontier-capacity --frontier --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.session.id')" = "frontier-capacity" ]
  [ "$(printf '%s' "$output" | jq -r '.session.meeting_type')" = "frontier" ]
  [ "$(printf '%s' "$output" | jq -r '.session.participants | join(",")')" = "claude,gemini,codex,antigravity" ]
  [ "$(jq -r '.id' "$ZSYNOD_DIR/sessions/frontier-capacity.json")" = "frontier-capacity" ]
  [ "$(jq -r '.last_seq' "$ZSYNOD_DIR/sessions/frontier-capacity.json")" = "1" ]
  [ "$(wc -l < "$ZSYNOD_DIR/sessions/frontier-capacity.turns.jsonl" | tr -d ' ')" = "1" ]
}

@test "zsynod turn --session resumes from last session seq when since is omitted" {
  "$REPO_ROOT/bin/zsynod" --as mike propose "First topic" >/dev/null
  "$REPO_ROOT/bin/zsynod" turn --session working-group --participants codex,gemini --json >/dev/null
  "$REPO_ROOT/bin/zsynod" --as codex speak P1 "new entry" >/dev/null

  run "$REPO_ROOT/bin/zsynod" turn --session working-group --participants codex,gemini --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.since')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.entries_since | length')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.entries_since[0].seq')" = "2" ]
  [ "$(printf '%s' "$output" | jq -r '.session.participants | join(",")')" = "codex,gemini" ]
  [ "$(jq -r '.turn_count' "$ZSYNOD_DIR/sessions/working-group.json")" = "2" ]
}

@test "zsynod committee records a durable named special committee" {
  run "$REPO_ROOT/bin/zsynod" --as mike committee ai-collab --purpose "Improve collaboration between AI integrations" --participants codex,gemini

  [ "$status" -eq 0 ]
  [[ "$output" == *"committee ai-collab"* ]]
  [ "$(jq -r 'select(.type=="committee") | .data.id' "$ZSYNOD_DIR/ledger.jsonl")" = "ai-collab" ]
  [ "$(jq -r '.kind' "$ZSYNOD_DIR/sessions/ai-collab.json")" = "committee" ]
  [ "$(jq -r '.purpose' "$ZSYNOD_DIR/sessions/ai-collab.json")" = "Improve collaboration between AI integrations" ]
  [ "$(jq -r '.participants | join(",")' "$ZSYNOD_DIR/sessions/ai-collab.json")" = "codex,gemini" ]
  [ "$(jq -r '.meeting_type' "$ZSYNOD_DIR/sessions/ai-collab.json")" = "committee" ]

  run "$REPO_ROOT/bin/zsynod" committees
  [ "$status" -eq 0 ]
  [[ "$output" == *"ai-collab"* ]]
}

@test "zsynod turn inherits committee participants and purpose metadata" {
  "$REPO_ROOT/bin/zsynod" --as mike committee ai-collab --purpose "Improve collaboration between AI integrations" --participants codex,gemini >/dev/null
  "$REPO_ROOT/bin/zsynod" --as mike propose "Committee follow-up" >/dev/null

  run "$REPO_ROOT/bin/zsynod" turn --session ai-collab --json

  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.session.meeting_type')" = "committee" ]
  [ "$(printf '%s' "$output" | jq -r '.session.participants | join(",")')" = "codex,gemini" ]
  [ "$(printf '%s' "$output" | jq -r '.since')" = "1" ]
  [ "$(printf '%s' "$output" | jq -r '.entries_since[0].type')" = "propose" ]
  [ "$(jq -r '.kind' "$ZSYNOD_DIR/sessions/ai-collab.json")" = "committee" ]
  [ "$(jq -r '.purpose' "$ZSYNOD_DIR/sessions/ai-collab.json")" = "Improve collaboration between AI integrations" ]
  [ "$(jq -r '.turn_count' "$ZSYNOD_DIR/sessions/ai-collab.json")" = "1" ]
}

@test "zsynod turn rejects invalid session id and unknown participants" {
  run "$REPO_ROOT/bin/zsynod" turn --session "../bad"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid session id"* ]]

  run "$REPO_ROOT/bin/zsynod" turn --participants codex,unknown
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown participant: unknown"* ]]
}
