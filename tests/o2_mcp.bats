#!/usr/bin/env bats
# tests/o2_mcp.bats — o2-mcp server: protocol and tool dispatch tests
#
# Test groups:
#   A. Protocol    — initialize, tools/list, ping, notifications
#   B. Parse       — malformed JSON, empty input
#   C. Tool calls  — shape and success path (server may be down; checks structure only)
#   D. Error paths — unknown tool
#   E. Contract    — schema shape, name/count parity, dispatch/advertise parity
#   F. Spec 2026-07-28 — server/discover, resultType, deterministic ordering

bats_require_minimum_version 1.5.0

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
  O2_MCP="$BIN/o2-mcp"
}

_mcp() {
  printf '%s\n' "$@" \
    | ZDOTDIR="$REPO_ROOT" timeout 10 "$O2_MCP" 2>/dev/null
}

_call_tool() {
  local name="$1" args="$2"
  [[ -z "$args" ]] && args='{}'
  _mcp "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"${name}\",\"arguments\":${args}}}"
}

# ===========================================================================
# A. Protocol
# ===========================================================================

@test "A1: initialize returns protocolVersion" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
  version=$(printf '%s\n' "$response" | jq -r '.result.protocolVersion')
  [ -n "$version" ]
}

@test "A2: initialize response includes serverInfo.name = o2-mcp" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
  name=$(printf '%s\n' "$response" | jq -r '.result.serverInfo.name')
  [ "$name" = "o2-mcp" ]
}

@test "A3: initialize response includes tools capability" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
  printf '%s\n' "$response" | jq -e '.result.capabilities.tools' >/dev/null
}

@test "A4: tools/list returns non-empty tools array" {
  response=$(_mcp '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
  count=$(printf '%s\n' "$response" | jq '.result.tools | length')
  [ "${count:-0}" -gt 0 ]
}

@test "A5: ping returns empty result" {
  response=$(_mcp '{"jsonrpc":"2.0","id":3,"method":"ping"}')
  printf '%s\n' "$response" | jq -e '.result.resultType == "complete"' >/dev/null
}

@test "A6: unknown method with id returns result (not error)" {
  response=$(_mcp '{"jsonrpc":"2.0","id":4,"method":"notifications/initialized"}')
  printf '%s\n' "$response" | jq -e 'has("result")' >/dev/null
}

@test "A7: unknown method notification (no id) produces no output" {
  output=$(_mcp '{"jsonrpc":"2.0","method":"notifications/initialized"}')
  [ -z "$output" ]
}

# ===========================================================================
# B. Parse errors
# ===========================================================================

@test "B1: malformed JSON returns parse error code -32700" {
  response=$(_mcp 'not valid json')
  code=$(printf '%s\n' "$response" | jq -r '.error.code')
  [ "$code" = "-32700" ]
}

@test "B2: empty lines produce no output" {
  output=$(_mcp '' '' '')
  [ -z "$output" ]
}

@test "B3: multiple messages return multiple responses in order" {
  responses=$(
    _mcp \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
      '{"jsonrpc":"2.0","id":2,"method":"ping"}'
  )
  id1=$(printf '%s\n' "$responses" | jq -sr '.[0].id')
  id2=$(printf '%s\n' "$responses" | jq -sr '.[1].id')
  [ "$id1" = "1" ]
  [ "$id2" = "2" ]
}

# ===========================================================================
# C. Tool calls — structural shape (server may be down; validates envelope)
# ===========================================================================

@test "C1: o2_errors returns content array" {
  response=$(_call_tool "o2_errors" '{"since":"1h","limit":5}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C2: o2_slow returns content array" {
  response=$(_call_tool "o2_slow" '{"since":"1h","threshold":100}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C3: o2_failures returns content array" {
  response=$(_call_tool "o2_failures" '{"since":"1h"}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C4: o2_service returns content array" {
  response=$(_call_tool "o2_service" '{"since":"1h"}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C5: o2_logs returns content array" {
  response=$(_call_tool "o2_logs" '{"since":"1h","grep":"error"}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C6: o2_trace returns content array" {
  response=$(_call_tool "o2_trace" '{"trace_id":"deadbeef"}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

# ===========================================================================
# D. Error paths
# ===========================================================================

@test "D1: unknown tool name returns isError:true" {
  response=$(_call_tool "no_such_tool_xyz")
  is_error=$(printf '%s\n' "$response" | jq -r '.result.isError')
  [ "$is_error" = "true" ]
}

@test "D2: parse error response is valid JSON-RPC error envelope" {
  response=$(_mcp '{bad json')
  printf '%s\n' "$response" | jq -e '.jsonrpc == "2.0" and .error.code and .error.message' >/dev/null
}

# ===========================================================================
# E. Contract
# ===========================================================================

@test "E1: all advertised tools have non-empty name and description" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  printf '%s\n' "$response" | jq -e '
    .result.tools | all(
      (.name | type == "string" and length > 0) and
      (.description | type == "string" and length > 0)
    )
  ' >/dev/null
}

@test "E2: all advertised tools have inputSchema with type:object" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  printf '%s\n' "$response" | jq -e '
    .result.tools | all(.inputSchema.type == "object")
  ' >/dev/null
}

@test "E3: tools/list advertises exactly 6 tools" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  count=$(printf '%s\n' "$response" | jq '.result.tools | length')
  [ "$count" -eq 6 ]
}

@test "E4: advertised tool names match expected set" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  names=$(printf '%s\n' "$response" | jq -r '.result.tools[].name' | sort | tr '\n' ',')
  [ "$names" = "o2_errors,o2_failures,o2_logs,o2_service,o2_slow,o2_trace," ]
}

@test "E5: every dispatched tool is advertised (no silent dispatch)" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  advertised=$(printf '%s\n' "$response" | jq -r '.result.tools[].name' | sort)
  dispatched="o2_errors o2_failures o2_logs o2_service o2_slow o2_trace"
  for tool in $dispatched; do
    printf '%s\n' "$advertised" | grep -qx "$tool" || { echo "DISPATCH GAP: $tool not in tools/list"; false; }
  done
}

# ===========================================================================
# F. Spec 2026-07-28
# ===========================================================================

@test "F1: server/discover returns supported protocol versions including 2026-07-28" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"server/discover","params":{}}')
  printf '%s\n' "$response" | jq -e '.result.protocolVersions | index("2026-07-28") != null' >/dev/null
}

@test "F2: every result includes resultType complete" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  printf '%s\n' "$response" | jq -e '.result.resultType == "complete"' >/dev/null
}

@test "F3: tools/list is deterministically ordered by name" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  names=$(printf '%s\n' "$response" | jq -r '.result.tools[].name')
  sorted=$(printf '%s\n' "$names" | sort)
  [ "$names" = "$sorted" ]
}
