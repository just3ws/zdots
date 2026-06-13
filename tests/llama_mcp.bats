#!/usr/bin/env bats
# tests/llama_mcp.bats — llama-mcp server: protocol and tool dispatch tests
#
# Test groups:
#   A. Protocol    — initialize, tools/list, ping, notifications
#   B. Parse       — malformed JSON, empty input
#   C. Tool calls  — shape and success path (server may be down; checks structure only)
#   D. Error paths — unknown tool
#   E. Contract    — schema shape, name/count parity

bats_require_minimum_version 1.5.0

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"
  LLAMA_MCP="$BIN/llama-mcp"
}

_mcp() {
  printf '%s\n' "$@" \
    | ZDOTDIR="$REPO_ROOT" ZDOTS_AI_ENDPOINT="http://127.0.0.1:19999" \
      timeout 10 "$LLAMA_MCP" 2>/dev/null
}

_call_tool() {
  local name="$1" args="${2:-{}}"
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

@test "A2: initialize response includes serverInfo.name = llama-mcp" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
  name=$(printf '%s\n' "$response" | jq -r '.result.serverInfo.name')
  [ "$name" = "llama-mcp" ]
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
  printf '%s\n' "$response" | jq -e '.result == {}' >/dev/null
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

@test "B3: multiple messages return multiple responses" {
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

@test "C1: llama_capabilities returns content array" {
  response=$(_call_tool "llama_capabilities" '{"format":"markdown"}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C2: llama_health returns content array" {
  response=$(_call_tool "llama_health")
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C3: llama_config returns content array" {
  response=$(_call_tool "llama_config")
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C4: llama_run_test with quick mode returns content array" {
  response=$(_call_tool "llama_run_test" '{"mode":"quick"}')
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C5: llama_integration_snippet returns content for ruby_llm framework" {
  response=$(_call_tool "llama_integration_snippet" '{"framework":"ruby_llm"}')
  printf '%s\n' "$response" | jq -e '.result.content[0].text | length > 0' >/dev/null
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

@test "E3: tools/list advertises exactly 5 tools" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  count=$(printf '%s\n' "$response" | jq '.result.tools | length')
  [ "$count" -eq 5 ]
}

@test "E4: advertised tool names match expected set" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  names=$(printf '%s\n' "$response" | jq -r '.result.tools[].name' | sort | tr '\n' ',')
  [ "$names" = "llama_capabilities,llama_config,llama_health,llama_integration_snippet,llama_run_test," ]
}
