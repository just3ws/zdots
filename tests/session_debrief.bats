#!/usr/bin/env bats
# tests/session_debrief.bats — Infer → Curate write-back (closes the Virtuous Loop)
#
# Read side is injected via --input (deterministic, no live db). Write side is
# stubbed via SESSION_DEBRIEF_CTX (captures add-lesson calls without touching the
# Knowledge Layer). The seen-file is isolated via XDG_STATE_HOME so dedup state
# never leaks between tests or into the real state dir.

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin/session-debrief"

  export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
  WRITES="$BATS_TEST_TMPDIR/writes.log"

  # Stub zdots-ctx: log every add-lesson invocation, succeed.
  CTX_STUB="$BATS_TEST_TMPDIR/zdots-ctx"
  cat > "$CTX_STUB" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$WRITES"
exit 0
EOF
  chmod +x "$CTX_STUB"
  export SESSION_DEBRIEF_CTX="$CTX_STUB"

  # Canonical HI report: one high, one medium, one info.
  HI="$BATS_TEST_TMPDIR/hi.json"
  cat > "$HI" <<'JSON'
{"window_days":1,"signals":[
 {"severity":"high","kind":"phi","message":"21 commands suppressed via scrub_failure."},
 {"severity":"medium","kind":"reliability","message":"'zdots-doctor' failed 2/3 runs (67%)."},
 {"severity":"info","kind":"capture","message":"atuin unavailable."}
]}
JSON
}

@test "sd: --help exits 0 with usage" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "sd: --json emits the declared schema" {
  run "$BIN" --input "$HI" --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.schema == "zdots.session-debrief.v1"' >/dev/null
}

@test "sd: default min-severity medium proposes high+medium (not info)" {
  run "$BIN" --input "$HI" --json
  printf '%s\n' "$output" | jq -e '.proposed == 2' >/dev/null
  printf '%s\n' "$output" | jq -e '.high_severity == 1' >/dev/null
}

@test "sd: --min-severity high proposes only the high signal" {
  run "$BIN" --input "$HI" --json --min-severity high
  printf '%s\n' "$output" | jq -e '.proposed == 1' >/dev/null
}

@test "sd: --min-severity info proposes all three" {
  run "$BIN" --input "$HI" --json --min-severity info
  printf '%s\n' "$output" | jq -e '.proposed == 3' >/dev/null
}

@test "sd: phi signal carries phi+session-debrief+accountability tags" {
  run "$BIN" --input "$HI" --json --min-severity high
  printf '%s\n' "$output" | jq -e '
    .lessons[0].tags == ["phi","session-debrief","accountability"]
  ' >/dev/null
}

@test "sd: --dry-run writes nothing" {
  run "$BIN" --input "$HI" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "$WRITES" ]
}

@test "sd: --yes writes one add-lesson per proposed signal" {
  run "$BIN" --input "$HI" --yes
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$WRITES")" -eq 2 ]
  grep -q "add-lesson" "$WRITES"
}

@test "sd: written lesson includes content, context, and tags as args" {
  run "$BIN" --input "$HI" --yes --min-severity high
  line=$(grep "scrub_failure" "$WRITES")
  [[ "$line" == add-lesson* ]]
  [[ "$line" == *"session-debrief"* ]]
  [[ "$line" == *"accountability"* ]]
}

@test "sd: dedup skips signals already debriefed on a second run" {
  "$BIN" --input "$HI" --yes
  run "$BIN" --input "$HI" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"already debriefed"* ]]
  # Still only the original 2 writes — no duplicates.
  [ "$(wc -l < "$WRITES")" -eq 2 ]
}

@test "sd: --no-dedup re-curates previously seen signals" {
  "$BIN" --input "$HI" --yes
  run "$BIN" --input "$HI" --yes --no-dedup
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$WRITES")" -eq 4 ]
}

@test "sd: empty signal set is a clean no-op" {
  echo '{"window_days":1,"signals":[]}' > "$BATS_TEST_TMPDIR/empty.json"
  run "$BIN" --input "$BATS_TEST_TMPDIR/empty.json" --yes
  [ "$status" -eq 0 ]
  [ ! -f "$WRITES" ]
}

@test "sd: all-deduped second run does not crash under set -u" {
  "$BIN" --input "$HI" --yes
  # Every signal now seen; the proposal arrays are empty — must not trip set -u.
  run "$BIN" --input "$HI" --yes
  [ "$status" -eq 0 ]
  [[ "$output" != *"unbound variable"* ]]
}

@test "sd: stdin input via --input -" {
  run bash -c "cat '$HI' | '$BIN' --input - --json"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.proposed == 2' >/dev/null
}

@test "sd: invalid JSON input fails cleanly" {
  echo 'not json' > "$BATS_TEST_TMPDIR/bad.json"
  run "$BIN" --input "$BATS_TEST_TMPDIR/bad.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"valid JSON"* ]]
}

@test "sd: write failure is reported and exits non-zero" {
  # Stub that fails every write.
  cat > "$CTX_STUB" <<EOF
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$CTX_STUB"
  run "$BIN" --input "$HI" --yes --min-severity high
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed"* ]]
}

@test "sd: failed write is not recorded as seen (retryable)" {
  cat > "$CTX_STUB" <<EOF
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$CTX_STUB"
  "$BIN" --input "$HI" --yes --min-severity high || true
  [ ! -f "$XDG_STATE_HOME/zdots/session-debrief.seen" ] || \
    [ "$(wc -l < "$XDG_STATE_HOME/zdots/session-debrief.seen")" -eq 0 ]
}
