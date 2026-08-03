#!/usr/bin/env bats
# tests/svc_map.bats — the discovery-layer contract (lib/svc-map.bash).
#
# Pure data, always testable: every managed + health-only service must have
# at least a purpose, and `zsvc map --json` must emit parseable JSON.

setup() {
  load "setup.bash"
  setup_environment
  source "$REPO_ROOT/lib/svc-registry.bash"
  source "$REPO_ROOT/lib/svc-map.bash"
}

@test "svc-map: every registered service has a purpose" {
  for s in llama embed otel o2 colima nginx postgres redis worker status gemstash ctx; do
    run zdots_svc_purpose "$s"
    [ -n "$output" ]
  done
}

@test "svc-map: depends_on only references known canonical services" {
  local s dep
  for s in llama embed otel o2 colima nginx postgres redis worker status gemstash ctx; do
    for dep in $(zdots_svc_depends_on "$s"); do
      run zdots_svc_resolve "$dep"
      [ "$status" -eq 0 ]
    done
  done
}

@test "zsvc map --json emits valid JSON with one entry per service" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  run "$REPO_ROOT/bin/zsvc" map --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.services | length == 11' >/dev/null
}

@test "zsvc map llama --json includes purpose, auth, and example" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  run "$REPO_ROOT/bin/zsvc" map llama --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.services[0].purpose | length > 0' >/dev/null
  echo "$output" | jq -e '.services[0].auth | length > 0' >/dev/null
  echo "$output" | jq -e '.services[0].example | length > 0' >/dev/null
}
