#!/usr/bin/env bats
# zsynod exec-tick — bounded frontier execution. Dispatch is stubbed
# (ZSYNOD_DISPATCH=0 returns a marker-wrapped diff) so no cloud calls happen.

setup() {
  ZSYNOD="${BATS_TEST_DIRNAME}/../bin/zsynod"
  TMP="$(mktemp -d)"
  export ZSYNOD_DIR="$TMP/zsynod"
  export ZSYNOD_MEMBER=claude
  export ZSYNOD_DISPATCH=0
  run "$ZSYNOD" init; [ "$status" -eq 0 ]
}
teardown() { rm -rf "$TMP"; }

@test "exec-tick with no open handoffs does nothing" {
  run "$ZSYNOD" exec-tick
  [ "$status" -eq 0 ]
  [[ "$output" == *"no open handoffs"* ]]
}

@test "exec-tick turns an open handoff into a queued one-shot diff (propose-not-apply)" {
  "$ZSYNOD" propose "Demo" --body b
  "$ZSYNOD" handoff --to aider --task "do the small thing" --ref P1
  run "$ZSYNOD" exec-tick
  [ "$status" -eq 0 ]
  [[ "$output" == *"queued Q1"* ]] || [[ "$output" == *"queued"* ]]
  # a queued item exists, nothing applied
  grep -q '"type":"queued"' "$ZSYNOD_DIR/ledger.jsonl"
  grep -q '"type":"exec"' "$ZSYNOD_DIR/ledger.jsonl"
  [ -f "$ZSYNOD_DIR/queue/Q1.patch" ]
  ! grep -q '"status":"applied"' "$ZSYNOD_DIR/ledger.jsonl"
  run "$ZSYNOD" verify; [ "$status" -eq 0 ]
}

@test "exec-tick does not re-process a handoff it already executed" {
  "$ZSYNOD" propose "Demo" --body b
  "$ZSYNOD" handoff --to aider --task "one thing" --ref P1
  "$ZSYNOD" exec-tick >/dev/null
  run "$ZSYNOD" exec-tick
  [ "$status" -eq 0 ]
  [[ "$output" == *"no open handoffs"* ]]
}

@test "the queued exec diff references the handoff's ref" {
  "$ZSYNOD" propose "Demo" --body b
  "$ZSYNOD" handoff --to aider --task "thing" --ref P1
  "$ZSYNOD" exec-tick >/dev/null
  run "$ZSYNOD" queue show Q1
  [ "$status" -eq 0 ]
  [[ "$output" == *"P1"* ]]
}
