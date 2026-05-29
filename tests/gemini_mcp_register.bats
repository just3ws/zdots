#!/usr/bin/env bats
# tests/gemini_mcp_register.bats — Contract tests for bin/gemini-mcp-register

setup() {
  load "setup.bash"
  setup_environment
  BIN="$REPO_ROOT/bin"

  # Scratch dir for fake gemini home and PATH-shimming
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.gemini"

  # Fake gemini CLI that records invocations and writes a minimal settings.json
  FAKE_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$FAKE_BIN"

  cat > "$FAKE_BIN/gemini" <<'FAKE'
#!/usr/bin/env bash
# Minimal gemini CLI stub for testing gemini-mcp-register.
# Records calls to $BATS_TEST_TMPDIR/gemini_calls and mutates
# $HOME/.gemini/settings.json like the real CLI.
set -euo pipefail
CALLS="${BATS_TEST_TMPDIR}/gemini_calls"
printf '%s\n' "$*" >> "$CALLS"

SETTINGS="$HOME/.gemini/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || printf '{}' > "$SETTINGS"

# Parse subcommand: mcp add / mcp remove / mcp list
if [[ "${1:-}" == "mcp" ]]; then
  sub="${2:-}"
  case "$sub" in
    add)
      name="$3"
      cmd="$4"
      # Extract env vars from -e KEY=value flags
      env_obj="{}"
      for arg in "$@"; do
        if [[ "$arg" =~ ^[A-Z_]+=.* ]]; then
          key="${arg%%=*}"
          val="${arg#*=}"
          env_obj=$(printf '%s' "$env_obj" | jq --arg k "$key" --arg v "$val" '.[$k]=$v')
        fi
      done
      tmp=$(mktemp)
      jq --arg n "$name" --arg c "$cmd" --argjson e "$env_obj" \
        '.mcpServers[$n] = {command: $c, args: [], env: $e}' "$SETTINGS" > "$tmp"
      mv "$tmp" "$SETTINGS"
      printf 'MCP server "%s" added to user settings. (stdio)\n' "$name"
      ;;
    remove)
      name="$3"
      tmp=$(mktemp)
      jq --arg n "$name" 'del(.mcpServers[$n])' "$SETTINGS" > "$tmp"
      mv "$tmp" "$SETTINGS"
      printf 'Server "%s" removed from user settings.\n' "$name"
      ;;
    list)
      servers=$(jq -r '.mcpServers // {} | keys[]' "$SETTINGS" 2>/dev/null || true)
      if [[ -z "$servers" ]]; then
        printf 'No MCP servers configured.\n'
      else
        printf '%s\n' "$servers"
      fi
      ;;
  esac
fi
FAKE
  chmod +x "$FAKE_BIN/gemini"
  chmod +x "$FAKE_BIN/jq" 2>/dev/null || ln -sf "$(command -v jq)" "$FAKE_BIN/jq"

  export PATH="$FAKE_BIN:$PATH"
  export HOME="$FAKE_HOME"
}

_run_register() {
  ZDOTDIR="$REPO_ROOT" run "$BIN/gemini-mcp-register" "$@"
}

# ---------------------------------------------------------------------------
# --help
# ---------------------------------------------------------------------------

@test "gemini-mcp-register: --help exits 0" {
  run "$BIN/gemini-mcp-register" --help
  [ "$status" -eq 0 ]
}

@test "gemini-mcp-register: --help output goes to stdout" {
  run "$BIN/gemini-mcp-register" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--force"* ]]
}

@test "gemini-mcp-register: --help lists both servers" {
  run "$BIN/gemini-mcp-register" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"ctx"* ]]
  [[ "$output" == *"llama"* ]]
}

@test "gemini-mcp-register: unknown option exits 2" {
  run "$BIN/gemini-mcp-register" --bogus
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Guard: gemini CLI missing
# ---------------------------------------------------------------------------

@test "gemini-mcp-register: exits 1 when gemini CLI not found" {
  # Use a minimal PATH containing only required POSIX tools — no gemini
  run env PATH="/usr/bin:/bin" ZDOTDIR="$REPO_ROOT" HOME="$FAKE_HOME" \
    bash "$BIN/gemini-mcp-register"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gemini CLI not found"* ]]
}

# ---------------------------------------------------------------------------
# Normal registration
# ---------------------------------------------------------------------------

@test "gemini-mcp-register: registers ctx and llama servers" {
  _run_register
  [ "$status" -eq 0 ]
  settings="$HOME/.gemini/settings.json"
  [ -f "$settings" ]
  jq -e '.mcpServers.ctx' "$settings" >/dev/null
  jq -e '.mcpServers.llama' "$settings" >/dev/null
}

@test "gemini-mcp-register: ctx server command points to ctx-mcp" {
  _run_register
  cmd=$(jq -r '.mcpServers.ctx.command' "$HOME/.gemini/settings.json")
  [[ "$cmd" == *"ctx-mcp" ]]
}

@test "gemini-mcp-register: llama server command points to llama-mcp" {
  _run_register
  cmd=$(jq -r '.mcpServers.llama.command' "$HOME/.gemini/settings.json")
  [[ "$cmd" == *"llama-mcp" ]]
}

@test "gemini-mcp-register: llama server env includes PATH with mise shims" {
  _run_register
  path_val=$(jq -r '.mcpServers.llama.env.PATH' "$HOME/.gemini/settings.json")
  [[ "$path_val" == *"mise/shims"* ]]
}

@test "gemini-mcp-register: llama server env includes ZDOTS_AI_ENDPOINT" {
  _run_register
  endpoint=$(jq -r '.mcpServers.llama.env.ZDOTS_AI_ENDPOINT' "$HOME/.gemini/settings.json")
  [[ "$endpoint" == http://* ]]
}

@test "gemini-mcp-register: ctx server env includes ZDOTDIR" {
  _run_register
  zdotdir=$(jq -r '.mcpServers.ctx.env.ZDOTDIR' "$HOME/.gemini/settings.json")
  [[ "$zdotdir" == "$REPO_ROOT" ]]
}

# ---------------------------------------------------------------------------
# Idempotency
# ---------------------------------------------------------------------------

@test "gemini-mcp-register: idempotent — second run exits 0 without re-registering" {
  _run_register
  [ "$status" -eq 0 ]
  calls_before=$(wc -l < "$BATS_TEST_TMPDIR/gemini_calls" 2>/dev/null || echo 0)

  _run_register
  [ "$status" -eq 0 ]
  [[ "$output" == *"already registered"* ]]
  calls_after=$(wc -l < "$BATS_TEST_TMPDIR/gemini_calls")
  # No new gemini mcp add calls on second run
  [ "$calls_after" -eq "$calls_before" ]
}

# ---------------------------------------------------------------------------
# --force
# ---------------------------------------------------------------------------

@test "gemini-mcp-register: --force re-registers existing servers" {
  _run_register
  [ "$status" -eq 0 ]

  _run_register --force
  [ "$status" -eq 0 ]
  [[ "$output" != *"already registered"* ]]
  # Both servers still present after force
  jq -e '.mcpServers.ctx' "$HOME/.gemini/settings.json" >/dev/null
  jq -e '.mcpServers.llama' "$HOME/.gemini/settings.json" >/dev/null
}

# ---------------------------------------------------------------------------
# ZDOTS_AI_ENDPOINT override
# ---------------------------------------------------------------------------

@test "gemini-mcp-register: respects ZDOTS_AI_ENDPOINT env var" {
  ZDOTDIR="$REPO_ROOT" ZDOTS_AI_ENDPOINT="http://powerstation.local:11500" \
    run "$BIN/gemini-mcp-register"
  [ "$status" -eq 0 ]
  endpoint=$(jq -r '.mcpServers.llama.env.ZDOTS_AI_ENDPOINT' "$HOME/.gemini/settings.json")
  [ "$endpoint" = "http://powerstation.local:11500" ]
}
