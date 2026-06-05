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
# Context window (32k total): system ~1k, history ~2k, read files ~2k,
# repo map ~2k, reasoning + files ~22k, output ceiling ~2k.
# Every token in the system prompt costs reasoning headroom — keep appends lean.
#
# Config lives in ~/.pi/agent/; the custom llamacpp provider is defined in
# ~/.pi/agent/models.json. Session history goes to XDG state dir.
# Telemetry is disabled unconditionally — PHI-adjacent machine.
#
# See PI.md for usage guidance and the Pi↔Aider boundary rules.

zdots_pi_init() {
  # Gate + locality in one call
  if ! typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1; then
    [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
  fi
  typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1 \
    && zdots_ai_gated_endpoint "zpi" >/dev/null

  # Prune Pi skills: only load project-local skills to avoid bloat/collisions.
  local _pi_skills_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pi/skills.tmp"
  mkdir -p "$_pi_skills_dir"
  # Clear existing links
  rm -f "$_pi_skills_dir"/*
  # Link only project-local skills
  if [[ -d "${ZDOTDIR}/.pi/skills" ]]; then
      find "${ZDOTDIR}/.pi/skills" -maxdepth 1 -mindepth 1 -type d -exec ln -s {} "$_pi_skills_dir/" \;
  fi
  export PI_SKILL_DIR="$_pi_skills_dir"

  # Telemetry off
  export PI_TELEMETRY=0

  # Redirect session history to XDG state dir.
  local _pi_state="${XDG_STATE_HOME:-$HOME/.local/state}/pi/agent/sessions"
  [[ -d "$_pi_state" ]] || mkdir -p "$_pi_state" 2>/dev/null
  export PI_CODING_AGENT_SESSION_DIR="$_pi_state"
}

# zpi — launch Pi wired to local llama.cpp, boundary-enforced.
#
# Usage:
#   zpi                        # interactive session
#   zpi "explain this module"  # interactive with opening prompt
#   zpi -p "explain"           # non-interactive, print and exit
#
# Auto-appends:
#   PI.md        — zdots Pi guidance (always)
#   AGENT.md     — project-local guide if present in $PWD
#   pi-ctx-brief — compact KB/AI status (~120 tokens) injected via temp file
#
# Skips pi-ctx-brief if it fails or produces no output (offline, DB down).
zpi() {
  zdots_pi_init
  local _pi_system_append=()

  [[ -r "${ZDOTDIR}/PI.md" ]] \
    && _pi_system_append+=(--append-system-prompt "${ZDOTDIR}/PI.md")

  [[ -r "${PWD}/AGENT.md" ]] \
    && _pi_system_append+=(--append-system-prompt "${PWD}/AGENT.md")

  # Inject compact KB+AI status without burning context on a full hydration.
  # Write to a temp file — Pi's --append-system-prompt accepts a file path.
  local _brief_file
  _brief_file=$(mktemp 2>/dev/null) || true
  if [[ -n "$_brief_file" ]]; then
    "${ZDOTDIR}/bin/pi-ctx-brief" > "$_brief_file" 2>/dev/null || true
    [[ -s "$_brief_file" ]] \
      && _pi_system_append+=(--append-system-prompt "$_brief_file")
  fi

  # Performance Auditing: Log utilization
  if [[ -n "$1" ]]; then
    zdots_trace_log "ai_query" "tool=zpi,prompt=${1[1,128]}"
  else
    zdots_trace_log "ai_query" "tool=zpi,mode=interactive"
  fi

  pi "${_pi_system_append[@]}" "$@"

  [[ -n "$_brief_file" ]] && rm -f "$_brief_file"
}
