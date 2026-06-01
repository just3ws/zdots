#!/usr/bin/env bash
# lib/trace_log.bash — Cross-shell trace logging for Bash and Zsh.
#
# Provides a shell-agnostic version of zdots_trace_log that writes to the
# standard traces.jsonl file. Used by bin/ scripts (Bash) where the Zsh-specific
# providers/trace/*.zsh functions are unavailable.
#
# RATIONALE:
# Performance auditing requires instrumentation across both the interactive 
# shell (Zsh) and background/orchestration scripts (Bash).

zdots_trace_log() {
  local event_type="$1"
  local data="$2"
  local trace_file="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/traces.jsonl"
  
  # 1. Ensure restricted directory (700)
  if [ ! -d "${trace_file%/*}" ]; then
    mkdir -p "${trace_file%/*}" 2>/dev/null
    chmod 700 "${trace_file%/*}" 2>/dev/null || true
  fi
  
  # 2. Timestamp (Bash 4.2+ has printf %(...)T, but date is more portable)
  local timestamp
  if [ -n "${BASH_VERSION:-}" ]; then
    # shellcheck disable=SC2183
    printf -v timestamp '%(%Y-%m-%dT%H:%M:%S%z)T' -1 2>/dev/null || timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z')
  else
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z')
  fi
  
  # 3. Simple JSON escaping (double quotes only)
  local escaped_data="${data//\"/\\\"}"
  
  # 4. Write entry
  # sid/spid fall back to process-based IDs if the shell trace environment is absent.
  printf '{"ts":"%s","sid":"%s","spid":"%s","event":"%s","data":"%s"}\n' \
    "$timestamp" \
    "${ZDOTS_TRACE_ID:-session-$$}" \
    "${ZDOTS_SPAN_ID:-span-$$}" \
    "$event_type" \
    "$escaped_data" \
    >> "$trace_file"
}
