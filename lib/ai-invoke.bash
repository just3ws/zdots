#!/usr/bin/env bash
# lib/ai-invoke.bash — AI Invocation Interface for the zdots content pipeline.
#
# The seam through which all local AI inference is called. Callers use these
# functions; they never call ai-query directly from lib code or shell functions.
#
# zdots_ai_infer_raw [--temperature N] [--thinking] PROMPT [SYSTEM_PROMPT]  — raw text inference, stdin → stdout
#   Gate check + locality assertion (exits 1/2 on failure).
#   Runs zdots_message_hygiene on input: normalize → PHI scrub. Owns hygiene.
#   Uses ai-query --mode raw (no safe-extract wrapping): callers construct the
#   full prompt — there is no untrusted data block to isolate, so injection
#   wrapping is unnecessary. PHI scrubbing runs regardless.
#   Used by zdots-ask (domain-routed prompts) and ZLE widgets.
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

# Prefer $ZDOTDIR/lib when available — works in both bash (BASH_SOURCE) and zsh
# (no BASH_SOURCE) contexts. Falls back to BASH_SOURCE for standalone bash use.
_AI_INVOKE_LIB_DIR="${ZDOTDIR:+${ZDOTDIR}/lib}"
_AI_INVOKE_LIB_DIR="${_AI_INVOKE_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)}"

# shellcheck source=lib/ai_boundary.bash
source "${_AI_INVOKE_LIB_DIR}/ai_boundary.bash"
# shellcheck source=lib/message_hygiene.bash
source "${_AI_INVOKE_LIB_DIR}/message_hygiene.bash"

# ---------------------------------------------------------------------------
# zdots_ai_infer_raw PROMPT [SYSTEM_PROMPT]
#
# Args:
#   $1  — user prompt (required; PHI-scrubbed internally by this function)
#   $2  — system prompt text (optional; pass "" to use the generic fallback)
#
# Stdout: raw model response text
# Exit:   0 on success, non-zero on gate failure or inference error
#
# Optional leading flags — the call contract lives in the signature (formerly
# callers had to `export` AIQ_* env vars; those are still honoured by ai-query as
# a back-compat fallback, but new callers pass flags):
#   --temperature N  — inference temperature (default: 0.2; use 0.1 for determinism)
#   --thinking       — enable Qwen3 thinking mode; think blocks stripped from output.
# ---------------------------------------------------------------------------
zdots_ai_infer_raw() {
  # Parse optional leading flags before the positional prompt/system args.
  local temperature="" thinking=""
  while [[ "${1:-}" == --* ]]; do
    case "$1" in
      --temperature) temperature="${2:-}"; shift 2 ;;
      --thinking)    thinking=1; shift ;;
      *) break ;;
    esac
  done
  local prompt="${1:-}"
  local system_prompt="${2:-}"

  if [[ -z "$prompt" ]]; then
    printf 'zdots_ai_infer_raw: prompt required\n' >&2
    return 2
  fi

  # Fast-fail UX gate: mode only (exits 2 if ZDOTS_AI_MODE=none), so a caller fails
  # cleanly before spawning the ai-query subprocess. This is NOT the security
  # boundary — the AUTHORITATIVE locality assertion (never send inference to a
  # non-local endpoint) is asserted exactly once, at the network call in aiq_submit
  # against the real endpoint. Do not re-add a locality check here.
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
  [[ -n "$temperature" ]] && ai_args+=(--temperature "$temperature")
  [[ -n "$thinking" ]] && ai_args+=(--think)
  [[ -n "$system_prompt" ]] && ai_args+=(--system "$system_prompt")

  # Suppress the "raw mode" warning: input is PHI-scrubbed above and the prompt
  # is caller-constructed (no untrusted data block), so the warning is a false
  # alarm for this path. See ai-query --mode raw for what the warning covers.
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

  # response_format: json_schema is NOT used here — grammar-based constrained
  # decoding conflicts with speculative decoding (draft tokens don't satisfy the
  # grammar; main model rejects them all and the server stalls). The schema is
  # enforced through the prompt and validated below. See AIQ_JSON_SCHEMA in
  # aiq_submit for the wiring; activate it once spec-draft is disabled.
  #
  # Lower temperature (0.1) for deterministic field values — passed as an explicit
  # parameter of the interface, no longer an exported env var.
  local raw
  if ! raw=$(zdots_ai_infer_raw --temperature 0.1 "$prompt"); then
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
