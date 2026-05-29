#!/usr/bin/env bats
# tests/mcp.bats — ctx-mcp server: protocol and tool dispatch tests
#
# Test groups:
#   A. Protocol    — initialize, tools/list, ping, notifications
#   B. Parse       — malformed JSON, empty input
#   C. Tool calls  — success path with mock zdots-ctx
#   D. Error paths — unknown tool, subprocess failure (Z-111 coverage)
#   E. Contract    — schema shape, advertised-vs-dispatched parity

bats_require_minimum_version 1.5.0

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"

  # Mock ZDOTDIR: minimal env.sh + controllable zdots-ctx
  MOCK_DIR="$BATS_TEST_TMPDIR/zdotdir"
  mkdir -p "$MOCK_DIR/bin"

  printf '#!/usr/bin/env bash\nexport ZDOTS_DATABASE_URL=postgresql://localhost/mock\n' \
    > "$MOCK_DIR/env.sh"

  cat > "$MOCK_DIR/bin/zdots-ctx" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  status)          printf '{"ok":true,"records":0}\n'; exit 0 ;;
  query)           printf 'mock result for: %s\n' "$2"; exit 0 ;;
  hydrate)         printf '{"context":"mock"}\n'; exit 0 ;;
  enqueue)         printf 'queued\n'; exit 0 ;;
  add-methodology) exit 0 ;;
  add-lesson)      exit 0 ;;
  capture)         printf '{"captured":true}\n'; exit 0 ;;
  living-docs)     printf 'synced\n'; exit 0 ;;
  *)               printf 'unknown: %s\n' "$1" >&2; exit 1 ;;
esac
MOCK
  chmod +x "$MOCK_DIR/bin/zdots-ctx"

  # Failure mock: all zdots-ctx calls exit 1
  FAIL_DIR="$BATS_TEST_TMPDIR/fail-zdotdir"
  mkdir -p "$FAIL_DIR/bin"
  printf '#!/usr/bin/env bash\nexport ZDOTS_DATABASE_URL=postgresql://localhost/mock\n' \
    > "$FAIL_DIR/env.sh"
  printf '#!/usr/bin/env bash\nprintf "zdots-ctx failed\n" >&2; exit 1\n' \
    > "$FAIL_DIR/bin/zdots-ctx"
  chmod +x "$FAIL_DIR/bin/zdots-ctx"
}

# Send one or more JSON-RPC messages to ctx-mcp; capture all output lines.
# NOTE: ZDOTDIR prefix must go on ruby (right-hand side of pipe), not on printf.
_mcp() {
  printf '%s\n' "$@" \
    | ZDOTDIR="$MOCK_DIR" timeout 5 ruby "$BIN/ctx-mcp" 2>/dev/null
}

_mcp_fail() {
  printf '%s\n' "$@" \
    | ZDOTDIR="$FAIL_DIR" timeout 5 ruby "$BIN/ctx-mcp" 2>/dev/null
}

_call_tool() {
  local name="$1" args="$2"
  [[ -z "$args" ]] && args='{}'
  _mcp "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"${name}\",\"arguments\":${args}}}"
}

_call_tool_fail() {
  local name="$1" args="$2"
  [[ -z "$args" ]] && args='{}'
  _mcp_fail "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"tools/call\",\"params\":{\"name\":\"${name}\",\"arguments\":${args}}}"
}

# ===========================================================================
# A. Protocol
# ===========================================================================

@test "A1: initialize returns protocolVersion 2024-11-05" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
  version=$(printf '%s\n' "$response" | jq -r '.result.protocolVersion')
  [ "$version" = "2024-11-05" ]
}

@test "A2: initialize response includes serverInfo.name" {
  response=$(_mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}')
  name=$(printf '%s\n' "$response" | jq -r '.result.serverInfo.name')
  [ "$name" = "ctx-mcp" ]
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

@test "A5: ping returns empty result object" {
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
  response=$(_mcp 'not valid json at all')
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
# C. Tool calls — success path
# ===========================================================================

@test "C1: ctx_status returns content array" {
  response=$(_call_tool "ctx_status")
  printf '%s\n' "$response" | jq -e '.result.content | arrays | length > 0' >/dev/null
}

@test "C2: ctx_query returns result text for given term" {
  response=$(_call_tool "ctx_query" '{"term":"pgvector","semantic":false}')
  text=$(printf '%s\n' "$response" | jq -r '.result.content[0].text')
  [[ "$text" == *"pgvector"* ]]
}

@test "C3: ctx_hydrate returns content" {
  response=$(_call_tool "ctx_hydrate" '{"tag":"testing"}')
  printf '%s\n' "$response" | jq -e '.result.content[0].text | length > 0' >/dev/null
}

@test "C4: ctx_enqueue returns success indicator" {
  response=$(_call_tool "ctx_enqueue" '{"type":"ingest","payload":"{\"url\":\"http://example.com\"}"}')
  text=$(printf '%s\n' "$response" | jq -r '.result.content[0].text')
  [[ "$text" == *"✅"* ]] || [[ "$text" == *"queued"* ]]
}

@test "C5: living_docs returns success indicator" {
  response=$(_call_tool "living_docs")
  text=$(printf '%s\n' "$response" | jq -r '.result.content[0].text')
  [[ "$text" == *"✅"* ]] || [[ "$text" == *"sync"* ]]
}

# ===========================================================================
# D. Error paths
# ===========================================================================

@test "D1: unknown tool name returns isError:true" {
  response=$(_call_tool "no_such_tool_xyz")
  is_error=$(printf '%s\n' "$response" | jq -r '.result.isError')
  [ "$is_error" = "true" ]
}

@test "D2: ctx_query subprocess failure returns error text, not empty" {
  response=$(_call_tool_fail "ctx_query" '{"term":"something","semantic":false}')
  text=$(printf '%s\n' "$response" | jq -r '.result.content[0].text')
  [ -n "$text" ]
  [[ "$text" == *"Error"* ]] || [[ "$text" == *"error"* ]] || [[ "$text" == *"failed"* ]]
}

@test "D3: ctx_status subprocess failure returns error text, not empty" {
  response=$(_call_tool_fail "ctx_status")
  text=$(printf '%s\n' "$response" | jq -r '.result.content[0].text')
  [ -n "$text" ]
  [[ "$text" == *"Error"* ]] || [[ "$text" == *"error"* ]]
}

@test "D4: ctx_hydrate subprocess failure returns error text" {
  response=$(_call_tool_fail "ctx_hydrate" '{"tag":"x"}')
  text=$(printf '%s\n' "$response" | jq -r '.result.content[0].text')
  [ -n "$text" ]
  [[ "$text" == *"Error"* ]] || [[ "$text" == *"error"* ]]
}

@test "D5: parse error response is valid JSON-RPC error envelope" {
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
  [ "$names" = "ctx_enqueue,ctx_hydrate,ctx_query,ctx_status,living_docs," ]
}
