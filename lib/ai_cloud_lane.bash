#!/usr/bin/env bash
# lib/ai_cloud_lane.bash — opt-in frontier (cloud) egress lane for AI tools.
#
# The default AI posture is local-only: ZDOTS_AI_MODE=local, a loopback/RFC-1918
# endpoint, enforced fail-closed by lib/ai_boundary.bash. This helper is the ONLY
# sanctioned path that crosses to a cloud frontier provider, and only by explicit
# per-invocation opt-in:
#
#   zaider --hf      → HuggingFace Inference Router   (HF_TOKEN)
#   zpi    --or      → OpenRouter                     (OPENROUTER_API_KEY)
#   zopencode --gh   → GitHub Copilot                 (opencode native auth)
#
# Contract (mirrors providers/tools/gh-models.zsh / zgh):
#   1. HARD refuse on work machines (ZDOTS_CONTEXT=work) — PHI hard boundary,
#      same posture .zdots.work enforces for ZDOTS_AI_MODE. Cloud egress of an
#      interactive coding session near PHI is never permitted on a work box.
#   2. Fail-closed: phi_scrub must be loadable before any egress is offered.
#   3. Resolve the API key from the macOS Keychain via zdots-keychain — never by
#      reading .zdots.secrets or any key file into the shell.
#   4. Emit a loud, HONEST notice: unlike zgh's one-shot path, phi_scrub CANNOT
#      sit in the loop of an interactive agent. The operator is the last gate.
#
# HONESTY NOTE: This guard establishes posture (home-only, scrubber present,
# key present) and warns. It does NOT and cannot auto-redact the interactive
# traffic of aider/pi/opencode. Do not type raw PHI/credentials into a cloud
# coding agent.
#
# Usage (from a provider's init function):
#   zdots_cloud_lane_guard "zaider --hf" HF_TOKEN || return $?
#   # on success: $ZDOTS_CLOUD_KEY holds the resolved key for the caller to use.

# Keychain command is overridable for tests (stub pattern).
: "${ZDOTS_KEYCHAIN_CMD:=zdots-keychain}"

# zdots_cloud_lane_guard TOOL [KEYVAR]
#   KEYVAR  — Keychain var to resolve into $ZDOTS_CLOUD_KEY. Omit or pass
#             "native" when the provider manages its own auth (e.g. opencode's
#             `opencode auth login` device flow for GitHub Copilot) — the guard
#             then runs the home-only + scrubber-posture checks and the notice
#             but resolves no zdots key.
zdots_cloud_lane_guard() {
  local tool="${1:?tool label required}"
  local keyvar="${2:-native}"

  # 1. Hard boundary: never on work machines.
  if [[ "${ZDOTS_CONTEXT:-}" == "work" ]]; then
    printf '%s: cloud lane refused — ZDOTS_CONTEXT=work (PHI hard boundary). Use the local model.\n' "$tool" >&2
    return 3
  fi

  # 2. Fail-closed: the scrubber must be loadable for the machine to be in a
  #    sane posture, even though it cannot intercept interactive agent traffic.
  if ! typeset -f phi_scrub >/dev/null 2>&1; then
    # shellcheck source=lib/phi_scrubber.bash
    [[ -r "${ZDOTDIR}/lib/phi_scrubber.bash" ]] && source "${ZDOTDIR}/lib/phi_scrubber.bash"
  fi
  if ! typeset -f phi_scrub >/dev/null 2>&1; then
    printf '%s: cloud lane refused — phi_scrub unavailable (no egress without the scrubber present).\n' "$tool" >&2
    return 1
  fi

  # 3. Resolve key from Keychain only — unless the provider self-manages auth.
  if [[ "$keyvar" != "native" ]]; then
    local key
    key="$("$ZDOTS_KEYCHAIN_CMD" get "$keyvar" 2>/dev/null)"
    if [[ -z "$key" ]]; then
      printf '%s: cloud lane refused — %s not in Keychain.\n' "$tool" "$keyvar" >&2
      printf '  Add it:  zdots-keychain add %s <value>\n' "$keyvar" >&2
      return 1
    fi
    export ZDOTS_CLOUD_KEY="$key"
  fi

  # 4. Loud, honest notice + audit trail.
  printf '\xe2\x9a\xa0 %s: CLOUD egress — prompts leave this machine to a frontier provider.\n' "$tool" >&2
  printf '  phi_scrub does NOT intercept interactive agent traffic. Do not type raw PHI/credentials.\n' >&2
  typeset -f zdots_audit_log >/dev/null 2>&1 && zdots_audit_log "cloud_lane" "tool=${tool} keyvar=${keyvar}"
  return 0
}
