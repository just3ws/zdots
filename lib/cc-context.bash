#!/usr/bin/env bash
# lib/cc-context.bash — resolve home/work context for Claude Code hooks,
# statusline, and doctor. Account-agnostic: it derives the answer from the
# machine's own config, never from the macOS username or git identity.
#
# Resolution order (first hit wins):
#   1. $ZDOTS_CONTEXT / $ZDOTS_AI_MODE if already exported into the shell
#   2. the value assigned in .zdots.local (works even if the calling shell
#      never sourced the zdots env — Claude Code spawns bare shells)
#   3. safe default (home / local)
#
# Why this matters: Claude Code is a CLOUD tool. On a work (PHI-adjacent)
# machine it must enforce local-only AI and the PHI deny-list (commits are now
# permitted within the zdots perimeter). These helpers let every hook reach the
# same verdict regardless of which account is logged in.

_cc_zdotdir() { printf '%s' "${ZDOTDIR:-$HOME/.config/zsh}"; }

# _cc_read_local VAR — echo the value assigned to VAR in .zdots.local, or "".
_cc_read_local() {
  local var="$1" f
  f="$(_cc_zdotdir)/.zdots.local"
  [[ -r "$f" ]] || return 0
  grep -E "^[[:space:]]*(export[[:space:]]+)?${var}=" "$f" 2>/dev/null \
    | tail -n1 \
    | sed "s/.*${var}=//; s/[\"']//g; s/[[:space:]].*//"
}

# cc_context → "work" or "home"
cc_context() {
  local v="${ZDOTS_CONTEXT:-}"
  [[ -z "$v" ]] && v="$(_cc_read_local ZDOTS_CONTEXT)"
  printf '%s' "${v:-home}"
}

# cc_ai_mode → "local" | "cloud" | "none"
cc_ai_mode() {
  local v="${ZDOTS_AI_MODE:-}"
  [[ -z "$v" ]] && v="$(_cc_read_local ZDOTS_AI_MODE)"
  printf '%s' "${v:-local}"
}

# cc_is_work — exit 0 when this machine is a work machine.
cc_is_work() { [[ "$(cc_context)" == "work" ]]; }
