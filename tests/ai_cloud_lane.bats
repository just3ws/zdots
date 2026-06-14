#!/usr/bin/env bats
# tests/ai_cloud_lane.bats — opt-in frontier (cloud) egress guard.
#
# Verifies the fail-closed contract of zdots_cloud_lane_guard: refused on work
# machines, refused without the scrubber, refused without the key, and on success
# resolves the key from a (stubbed) Keychain. No real cloud egress occurs.

setup() {
  load "setup.bash"
  setup_environment

  TMP="$(mktemp -d)"
  # Point the guard at a temp ZDOTDIR so it cannot source the real phi_scrubber
  # unless we deliberately define phi_scrub in the shell first.
  export ZDOTDIR="$TMP/zdots"
  mkdir -p "$ZDOTDIR/lib"

  # Stub Keychain: `keychain get HF_TOKEN` → prints a fake value; others empty.
  KC_STUB="$TMP/zdots-keychain"
  cat >"$KC_STUB" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "get" && "$2" == "HF_TOKEN" ]] && { printf 'fake-hf-token\n'; exit 0; }
exit 0
EOF
  chmod +x "$KC_STUB"
  export ZDOTS_KEYCHAIN_CMD="$KC_STUB"

  GUARD="$REPO_ROOT/lib/ai_cloud_lane.bash"
}

teardown() {
  rm -rf "$TMP"
}

# Run the guard in a clean bash with phi_scrub optionally defined.
_run_guard() {
  local define_scrub="$1"; shift
  local pre=""
  [[ "$define_scrub" == "scrub" ]] && pre='phi_scrub() { cat; };'
  run bash -c "
    export ZDOTDIR='$ZDOTDIR' ZDOTS_KEYCHAIN_CMD='$ZDOTS_KEYCHAIN_CMD' ZDOTS_CONTEXT='${ZDOTS_CONTEXT:-}'
    $pre
    source '$GUARD'
    zdots_cloud_lane_guard $* && printf 'KEY=%s\n' \"\${ZDOTS_CLOUD_KEY:-}\"
  "
}

@test "cloud-lane: refused on work machines (exit 3)" {
  ZDOTS_CONTEXT=work _run_guard scrub '"zaider --hf" HF_TOKEN'
  [ "$status" -eq 3 ]
  [[ "$output" == *"ZDOTS_CONTEXT=work"* ]]
}

@test "cloud-lane: refused without phi_scrub present (exit 1)" {
  ZDOTS_CONTEXT=home _run_guard noscrub '"zaider --hf" HF_TOKEN'
  [ "$status" -eq 1 ]
  [[ "$output" == *"phi_scrub unavailable"* ]]
}

@test "cloud-lane: refused when key absent from Keychain (exit 1)" {
  ZDOTS_CONTEXT=home _run_guard scrub '"zpi --or" OPENROUTER_API_KEY'
  [ "$status" -eq 1 ]
  [[ "$output" == *"not in Keychain"* ]]
}

@test "cloud-lane: success resolves key from Keychain and exports it" {
  ZDOTS_CONTEXT=home _run_guard scrub '"zaider --hf" HF_TOKEN'
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEY=fake-hf-token"* ]]
  [[ "$output" == *"CLOUD egress"* ]]
}

@test "cloud-lane: native mode succeeds without resolving any key" {
  ZDOTS_CONTEXT=home _run_guard scrub '"zopencode --gh" native'
  [ "$status" -eq 0 ]
  [[ "$output" == *"KEY="* ]]
  # No key exported in native mode.
  [[ "$output" != *"KEY=fake-hf-token"* ]]
}

@test "cloud-lane: notice is honest that interactive traffic is not scrubbed" {
  ZDOTS_CONTEXT=home _run_guard scrub '"zaider --hf" HF_TOKEN'
  [ "$status" -eq 0 ]
  [[ "$output" == *"does NOT intercept interactive"* ]]
}
