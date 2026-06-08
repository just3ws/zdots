#!/usr/bin/env bats
# tests/zsynod_minutes.bats — minutes generator must not let a multi-line remark
# (e.g. pasted markdown) inject headings or break out of its bullet. The ledger
# canon keeps the raw text; rendering flattens it. Regression for the P5/P6 bleed.

setup() {
  export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  TMP="$(mktemp -d)"
  export ZSYNOD_DIR="$TMP/zsynod"
  export ZDOTDIR="$REPO_ROOT"
  export ZSYNOD_MEMBER="claude"
  ZS="$REPO_ROOT/bin/zsynod"
  "$ZS" init >/dev/null 2>&1
}

teardown() { rm -rf "$TMP"; }

@test "minutes flattens a multi-line remark — no injected headings" {
  run "$ZS" propose "Bleed test proposal"
  [ "$status" -eq 0 ]
  pid="$(printf '%s\n' "$output" | sed -nE 's/.*proposed[^ ]* (P[0-9]+).*/\1/p' | head -1)"
  [ -n "$pid" ]

  # A remark carrying markdown headings and newlines — the exact shape that bled.
  "$ZS" speak "$pid" $'Implementation note: MVP added\n# zsynod turn\n## Proposals\n- **P1** committed' >/dev/null

  "$ZS" minutes >/dev/null

  # The remark's heading must not appear as a real heading line. ("## Proposals"
  # is a legitimate section heading, so assert on the unambiguous injected one.)
  run grep -nE '^#{1,6} zsynod turn$' "$ZSYNOD_DIR/minutes.md"
  [ "$status" -ne 0 ]

  # The remark text survives, flattened onto a single bullet line.
  run grep -F 'Implementation note: MVP added # zsynod turn ## Proposals' "$ZSYNOD_DIR/minutes.md"
  [ "$status" -eq 0 ]
}

@test "minutes still renders the canonical section headings" {
  run grep -cE '^## (Proposals|Awaiting you|Backlog deliberation|Open questions|Committees|Recent handoffs)' "$ZSYNOD_DIR/minutes.md"
  # minutes is generated lazily; generate it first
  "$ZS" minutes >/dev/null
  run grep -cE '^## (Proposals|Awaiting you \(blocking\)|Backlog deliberation|Open questions|Committees|Recent handoffs)' "$ZSYNOD_DIR/minutes.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 5 ]
}
