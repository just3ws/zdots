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
  # Optional first arg "or" selects the opt-in OpenRouter cloud lane. Bare `zpi`
  # is unchanged (local llama.cpp). Pi natively understands `--provider openrouter`
  # and reads OPENROUTER_API_KEY from the environment.
  local _mode="${1:-local}"

  if [[ "$_mode" == "or" ]]; then
    if ! typeset -f zdots_cloud_lane_guard >/dev/null 2>&1; then
      # shellcheck source=lib/ai_cloud_lane.bash
      [[ -r "${ZDOTDIR}/lib/ai_cloud_lane.bash" ]] && source "${ZDOTDIR}/lib/ai_cloud_lane.bash"
    fi
    typeset -f zdots_cloud_lane_guard >/dev/null 2>&1 \
      || { print -u2 "zpi --or: cloud lane guard unavailable."; return 1; }
    zdots_cloud_lane_guard "zpi --or" OPENROUTER_API_KEY || return $?
    export OPENROUTER_API_KEY="$ZDOTS_CLOUD_KEY"
  else
    # Gate + locality in one call
    if ! typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1; then
      [[ -r "${ZDOTDIR}/lib/ai_boundary.bash" ]] && source "${ZDOTDIR}/lib/ai_boundary.bash"
    fi
    typeset -f zdots_ai_gated_endpoint > /dev/null 2>&1 \
      && zdots_ai_gated_endpoint "zpi" >/dev/null
  fi

  # Prune Pi skills: only load project-local skills to avoid bloat/collisions.
  local _pi_skills_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pi/skills.tmp"
  mkdir -p "$_pi_skills_dir"
  # Clear existing links
  /bin/rm -f "$_pi_skills_dir"/*
  
  # Link only the project-local 'zdots' skill
  if [[ -d "${ZDOTDIR}/.pi/skills/zdots" ]]; then
      ln -s "${ZDOTDIR}/.pi/skills/zdots" "$_pi_skills_dir/"
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
  # Opt-in cloud lane: `zpi --or [...]` routes to OpenRouter (home-only,
  # scrubber-posture gated). Bare `zpi` is unchanged — local llama.cpp.
  local _mode="local"
  local _pi_provider_args=()
  if [[ "${1:-}" == "--or" ]]; then
    _mode="or"; shift
  fi
  zdots_pi_init "$_mode" || return $?
  if [[ "$_mode" == "or" ]]; then
    _pi_provider_args=(--provider openrouter --model "${ZDOTS_OR_MODEL:-anthropic/claude-3.7-sonnet}")
  fi
  local _pi_system_append=()
  local _pi_skill_args=()

  # 1. Clear + Link local skills
  local _pi_skills_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pi/skills.tmp"
  mkdir -p "$_pi_skills_dir"
  /bin/rm -f "$_pi_skills_dir"/*
  if [[ -d "${ZDOTDIR}/.pi/skills" ]]; then
      find "${ZDOTDIR}/.pi/skills" -maxdepth 1 -mindepth 1 -type d -exec ln -s {} "$_pi_skills_dir/" \;
  fi

  # 2. Prepare arguments to disable global skills and load project-local ones
  _pi_skill_args+=(--no-skills)
  _pi_skill_args+=(--skill "$_pi_skills_dir")

  # 3. Add context prompts
  [[ -r "${ZDOTDIR}/PI.md" ]] \
    && _pi_system_append+=(--append-system-prompt "${ZDOTDIR}/PI.md")

  [[ -r "${PWD}/AGENT.md" ]] \
    && _pi_system_append+=(--append-system-prompt "${PWD}/AGENT.md")

  local _brief_file
  _brief_file=$(mktemp 2>/dev/null) || true
  if [[ -n "$_brief_file" ]]; then
    "${ZDOTDIR}/bin/pi-ctx-brief" > "$_brief_file" 2>/dev/null || true
    [[ -s "$_brief_file" ]] \
      && _pi_system_append+=(--append-system-prompt "$_brief_file")
  fi

  # 4. Performance Auditing
  if [[ -n "$1" ]]; then
    zdots_trace_log "ai_query" "tool=zpi,lane=${_mode},prompt=${1[1,128]}"
  else
    zdots_trace_log "ai_query" "tool=zpi,lane=${_mode},mode=interactive"
  fi

  pi "${_pi_provider_args[@]}" "${_pi_skill_args[@]}" "${_pi_system_append[@]}" "$@"

  [[ -n "$_brief_file" ]] && rm -f "$_brief_file"
}
