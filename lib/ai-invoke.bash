#!/usr/bin/env bash
# lib/ai-invoke.bash — AI Invocation Interface for the zdots content pipeline.
#
# The seam through which all local AI inference is called. Callers use these
# functions; they never call ai-query directly from lib code or shell functions.
#
# zdots_ai_infer_raw PROMPT [SYSTEM_PROMPT]  — raw text inference, stdin → stdout
#   Gate check + locality assertion (exits 1/2 on failure).
#   Runs zdots_message_hygiene on input before submission.
#   No trust-boundary wrapping — assumes input is pre-scrubbed by caller.
#   Used by zdots-ask for domain-routed prompts.
#
# zdots_ai_distill PROMPT  — structured JSON inference, stdin → stdout (JSON)
#   Calls zdots_ai_infer_raw internally with JSON response format requested.
#   Validates that output parses as JSON before returning.
#   Used by zdots-ctx capture for session distillation.
#
# Caller contract: callers build and own the prompt. These functions own gate,
# hygiene, submission, and output parsing. Neither function constructs prompts.

[[ -n "${_AI_INVOKE_LOADED:-}" ]] && return 0
readonly _AI_INVOKE_LOADED=1

_AI_INVOKE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# shellcheck source=lib/ai_boundary.bash
source "${_AI_INVOKE_LIB_DIR}/ai_boundary.bash"
# shellcheck source=lib/message_hygiene.bash
source "${_AI_INVOKE_LIB_DIR}/message_hygiene.bash"

# ---------------------------------------------------------------------------
# zdots_ai_infer_raw PROMPT [SYSTEM_PROMPT]
#
# Args:
#   $1  — user prompt (required; pre-scrubbed by caller)
#   $2  — system prompt text (optional)
#
# Stdout: raw model response text
# Exit:   0 on success, non-zero on gate failure or inference error
# ---------------------------------------------------------------------------
zdots_ai_infer_raw() {
  local prompt="${1:-}"
  local system_prompt="${2:-}"

  if [[ -z "$prompt" ]]; then
    printf 'zdots_ai_infer_raw: prompt required\n' >&2
    return 2
  fi

  # Gate + locality enforced; exits 1 or 2 on violation
  zdots_ai_gate "zdots_ai_infer_raw"

  # Run hygiene pipeline: normalize → phi_scrub
  local clean_prompt
  clean_prompt=$(printf '%s' "$prompt" | zdots_message_hygiene) || return 1

  # ZDOTS_AI_QUERY allows tests to inject a mock without PATH manipulation.
  local ai_query="${ZDOTS_AI_QUERY:-${ZDOTDIR:-$HOME/.config/zsh}/bin/ai-query}"
  if [[ ! -x "$ai_query" ]]; then
    printf 'zdots_ai_infer_raw: ai-query not found or not executable: %s\n' "$ai_query" >&2
    return 1
  fi

  local ai_args=(--mode raw)
  [[ -n "$system_prompt" ]] && ai_args+=(--system "$system_prompt")

  AIQ_SUPPRESS_RAW_WARN=1 "$ai_query" "${ai_args[@]}" "$clean_prompt"
}

# ---------------------------------------------------------------------------
# zdots_ai_distill PROMPT
#
# Args:
#   $1  — distillation prompt (required; pre-scrubbed by caller)
#
# Stdout: validated JSON object
# Exit:   0 on success, 1 on inference error, 2 on invalid/empty JSON output
# ---------------------------------------------------------------------------
zdots_ai_distill() {
  local prompt="${1:-}"

  if [[ -z "$prompt" ]]; then
    printf 'zdots_ai_distill: prompt required\n' >&2
    return 2
  fi

  local raw
  if ! raw=$(zdots_ai_infer_raw "$prompt"); then
    printf 'zdots_ai_distill: inference failed\n' >&2
    return 1
  fi

  # Extract the first JSON object from the response (model may wrap with prose).
  # awk handles single-line and multi-line JSON; avoids BSD sed range ambiguity
  # when a line matches both the start ({) and end (}) patterns.
  local json
  json=$(printf '%s' "$raw" | awk '
    /^[[:space:]]*\{/ { in_json=1 }
    in_json { print }
    in_json && /\}[[:space:]]*$/ { exit }
  ')

  if [[ -z "$json" ]] || ! printf '%s' "$json" | jq empty 2>/dev/null; then
    printf 'zdots_ai_distill: model returned invalid or empty JSON\n' >&2
    return 2
  fi

  # Validate required fields are present and non-empty.
  local _field _val
  for _field in lesson summary intent result tags; do
    _val=$(printf '%s' "$json" | jq -r ".${_field} // empty" 2>/dev/null)
    if [[ -z "$_val" ]]; then
      printf 'zdots_ai_distill: required field missing or empty: .%s\n' "$_field" >&2
      return 2
    fi
  done

  printf '%s' "$json"
}
