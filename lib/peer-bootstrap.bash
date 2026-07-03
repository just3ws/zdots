# lib/peer-bootstrap.bash — Peer-aware Capability discovery (zdots ↔ adots).
#
# Single source of truth for AI-tool session bootstrap (ADR-0002 pattern: one
# implementation, thin adapters). Replaces the per-tool hook copies that
# drifted as untracked stubs in ~/.config/{pi,aider}/hooks/. Sourced by:
#
#   Claude Code — .claude/hooks/session_start §5 (sourced via cc-home)
#   Pi          — providers/tools/pi.zsh    (zdots_pi_init)
#   Aider       — providers/tools/aider.zsh (zdots_aider_init)
#   pi-ctx-brief — emits the model-visible peers line for Pi
#
# Bash- AND zsh-compatible; interactive-shell safe. The capability files run
# `set -euo pipefail` when sourced — leaking errexit/nounset into a user's
# interactive shell is a terminal-killing footgun, so caller option state is
# confined (zsh localoptions) or saved/restored (bash).
#
# Exports scalars ONLY — zsh cannot export arrays, and array exports were the
# silent no-op in the retired stubs. The capability ARRAYS still land in the
# sourcing shell (ZDOTS_CAPABILITIES, ADOTS_ALL_CAPABILITIES) for same-shell
# consumers like cc-home's banner.
#
#   ZDOTS_AVAILABLE / ADOTS_AVAILABLE — capability file sourced OK (0/1)
#   ZDOTS_PEER_CAPS / ADOTS_PEER_CAPS — "attested/declared", e.g. "119/122"
#   (probe) ZDOTS_HEALTHY / ADOTS_HEALTHY / PERSONAL_OS_READY
#
# Attested = the entry's command resolves via `command -v` in THIS shell — a
# Capability you can invoke right now, not one merely declared. The gap
# between the two numbers is a signal, not noise (see de95867: a banner that
# promises commands the agent can't run is worse than one that admits the gap).

# Fast discovery: source both peers' capability files, attest each entry.
# Idempotent per shell. Guard is deliberately NOT exported: a subshell
# inherits exported scalars but not the arrays, so it must re-bootstrap.
zdots_peer_bootstrap() {
  [ -n "${_ZDOTS_PEER_BOOTSTRAP_DONE:-}" ] && return 0

  # Confine option leaks from the sourced capability files.
  if [ -n "${ZSH_VERSION:-}" ]; then
    setopt localoptions 2>/dev/null
  fi
  local _restore_e=0 _restore_u=0 _restore_pf=0
  if [ -z "${ZSH_VERSION:-}" ]; then
    case "$-" in *e*) _restore_e=1 ;; esac
    case "$-" in *u*) _restore_u=1 ;; esac
    case "$(set -o 2>/dev/null)" in *"pipefail"*"on"*) _restore_pf=1 ;; esac
  fi
  set +e +u 2>/dev/null
  set +o pipefail 2>/dev/null

  local _zd="${ZDOTDIR:-${ZDOTS_DIR:-$HOME/.config/zsh}}"
  local _ad="${ADOTS_CONFIG_DIR:-$HOME/.config/adots}"

  export ZDOTS_AVAILABLE=0 ADOTS_AVAILABLE=0
  if [ -f "$_zd/etc/capabilities.sh" ]; then
    # shellcheck source=/dev/null
    source "$_zd/etc/capabilities.sh" 2>/dev/null && export ZDOTS_AVAILABLE=1
    set +e +u 2>/dev/null; set +o pipefail 2>/dev/null
  fi
  if [ -f "$_ad/capabilities.sh" ]; then
    # shellcheck source=/dev/null
    source "$_ad/capabilities.sh" 2>/dev/null && export ADOTS_AVAILABLE=1
    set +e +u 2>/dev/null; set +o pipefail 2>/dev/null
  fi

  # Attest: entry format "category:operation:command [args] — description";
  # the first word of the third field is the invocable command.
  local _entry _cmd _att _dec
  _att=0; _dec=${#ZDOTS_CAPABILITIES[@]}
  for _entry in "${ZDOTS_CAPABILITIES[@]}"; do
    _cmd="${_entry#*:}"; _cmd="${_cmd#*:}"; _cmd="${_cmd%% *}"
    command -v "$_cmd" >/dev/null 2>&1 && _att=$((_att + 1))
  done
  export ZDOTS_PEER_CAPS="${_att}/${_dec}"

  _att=0; _dec=${#ADOTS_ALL_CAPABILITIES[@]}
  for _entry in "${ADOTS_ALL_CAPABILITIES[@]}"; do
    _cmd="${_entry#*:}"; _cmd="${_cmd#*:}"; _cmd="${_cmd%% *}"
    command -v "$_cmd" >/dev/null 2>&1 && _att=$((_att + 1))
  done
  export ADOTS_PEER_CAPS="${_att}/${_dec}"

  # Deliberately NOT exporting ZDOTS_DIR/ADOTS_CONFIG_DIR here: capabilities.sh
  # readonly-pins ZDOTS_DIR, and in zsh a `readonly` run inside a function (this
  # source) leaves an empty function-local shadow — assigning through it is
  # fatal. Consumers already have ZDOTDIR (zsh) or set ZDOTS_DIR themselves.
  _ZDOTS_PEER_BOOTSTRAP_DONE=1

  if [ -z "${ZSH_VERSION:-}" ]; then
    [ "$_restore_e" = 1 ] && set -e
    [ "$_restore_u" = 1 ] && set -u
    [ "$_restore_pf" = 1 ] && set -o pipefail
  fi
  return 0
}

# Slow health probes — the two doctor runs cost seconds, so this is separate
# from bootstrap: cc-home opts in for its banner; interactive launchers
# (zpi/zaider) skip it to keep startup snappy and report availability only.
zdots_peer_probe() {
  local _zh=0 _ah=0
  { command -v zdots-doctor >/dev/null 2>&1 \
      && zdots-doctor --no-runtime >/dev/null 2>&1 && _zh=1; } || true
  { command -v adots-doctor >/dev/null 2>&1 \
      && adots-doctor >/dev/null 2>&1 && _ah=1; } || true
  export ZDOTS_HEALTHY="$_zh" ADOTS_HEALTHY="$_ah"
  export PERSONAL_OS_READY=$(( _zh & _ah ))
  return 0
}
