# providers/tools/pi.zsh — Pi coding agent wired to local llama.cpp server.
#
# Pi is @earendil-works/pi-coding-agent — a session-aware AI agent with tools
# (read, bash, edit, write) intended for interactive exploration and planning.
# It is the read/explore/plan half of the Pi↔Aider workflow:
#
#   zpi  "explain this module"      → Pi explores, reads, explains
#   zpi  "how should we fix X?"     → Pi plans; copy output to zaider
#   zaider --message "implement X"  → Aider executes, commits
#
# Config lives in ~/.pi/agent/; the custom llamacpp provider is defined in
# ~/.pi/agent/models.json. Session history goes to XDG state dir.
# Telemetry is disabled unconditionally — PHI-adjacent machine.
#
# See PI.md for usage guidance and the Pi↔Aider boundary rules.

zdots_pi_init() {
  # Gate + locality in one call — mode check and endpoint locality together.
  if ! typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1; then
    # shellcheck source=lib/ai_boundary.bash
    [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
  fi
  typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1 \
    && zdots_ai_gated_endpoint "zpi" >/dev/null

  # Telemetry off — no analytics from a PHI-adjacent machine.
  export PI_TELEMETRY=0

  # Redirect session history to XDG state dir.
  local _pi_state="${XDG_STATE_HOME:-$HOME/.local/state}/pi/agent/sessions"
  [[ -d "$_pi_state" ]] || mkdir -p "$_pi_state" 2>/dev/null
  export PI_CODING_AGENT_SESSION_DIR="$_pi_state"
}

# zpi — launch Pi wired to local llama.cpp, boundary-enforced.
# Usage:
#   zpi                        # interactive session
#   zpi "explain this module"  # one-shot prompt
#   zpi --print -p "explain"   # non-interactive, print output only
#
# Auto-appends AGENT.md from $PWD if present, after the zdots PI.md.
# Any project can define a token-efficient local guide this way.
zpi() {
  zdots_pi_init
  local _pi_system_append=()
  [[ -r "${ZDOTDIR}/PI.md" ]] && _pi_system_append+=(--append-system-prompt "${ZDOTDIR}/PI.md")
  [[ -r "${PWD}/AGENT.md" ]] && _pi_system_append+=(--append-system-prompt "${PWD}/AGENT.md")
  pi "${_pi_system_append[@]}" "$@"
}
