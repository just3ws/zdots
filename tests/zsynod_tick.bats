#!/usr/bin/env bats
# zsynod tick — one deliberation turn. Dispatch is stubbed (ZSYNOD_DISPATCH=0)
# so these tests never call a model: they exercise focus, append, and gating.

setup() {
  ZSYNOD="${BATS_TEST_DIRNAME}/../bin/zsynod"
  TMP="$(mktemp -d)"
  export ZSYNOD_DIR="$TMP/zsynod"
  export ZSYNOD_MEMBER=claude
  export ZSYNOD_DISPATCH=0          # stub all model calls
  run "$ZSYNOD" init
  [ "$status" -eq 0 ]
}

teardown() { rm -rf "$TMP"; }

@test "tick appends a discuss entry from pi and leaves the chain intact" {
  run "$ZSYNOD" tick --topic Z-999
  [ "$status" -eq 0 ]
  grep -q '"type":"discuss"' "$ZSYNOD_DIR/ledger.jsonl"
  grep -q '"actor":"pi"' "$ZSYNOD_DIR/ledger.jsonl"
  run "$ZSYNOD" verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"chain intact"* ]]
}

@test "tick --json emits a pipeable shape with topic and discussion" {
  run "$ZSYNOD" tick --topic Z-999 --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.topic == "Z-999"'
  echo "$output" | jq -e '.discussion | length >= 1'
  echo "$output" | jq -e 'has("asks_awaiting_approval")'
}

@test "tick without --frontier deliberates pi only (no codex/gemini)" {
  run "$ZSYNOD" tick --topic Z-999 --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.discussion[].actor] == ["pi"]'
}

@test "tick --frontier adds codex and gemini to the discussion" {
  run "$ZSYNOD" tick --topic Z-999 --frontier --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '[.discussion[].actor] | index("codex") != null'
  echo "$output" | jq -e '[.discussion[].actor] | index("gemini") != null'
}

@test "stub ASK is 'none' so no proposals/handoffs are auto-written (gated)" {
  run "$ZSYNOD" tick --topic Z-999 --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.asks_awaiting_approval == []'
  # nothing of type propose or handoff written by the tick
  ! grep -q '"type":"propose"' "$ZSYNOD_DIR/ledger.jsonl"
  ! grep -q '"type":"handoff"' "$ZSYNOD_DIR/ledger.jsonl"
}
