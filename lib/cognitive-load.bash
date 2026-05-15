#!/usr/bin/env bash
# lib/cognitive-load.bash — UX helpers for high cognitive load detection.
#
# RATIONALE:
# Implements "Cognitive Load Awareness" (Z-058).
# Detects frustration (repeated errors) and shifts the shell to "Calm Mode".

# zdots_check_cognitive_load [threshold] [minutes]
# Returns 1 (true) if error velocity exceeds threshold.
zdots_check_cognitive_load() {
  local threshold="${1:-3}"
  local minutes="${2:-5}"
  local velocity
  
  velocity=$("${ZDOTDIR}/bin/zdots-ctx" error-velocity "$minutes" 2>/dev/null || echo 0)
  
  if [[ "$velocity" -ge "$threshold" ]]; then
    return 0 # Success (Load is high)
  fi
  return 1 # Failure (Load is low)
}

# zdots_calm_mode
# Triggers visual cues and automated assistance for a frustrated user.
zdots_calm_mode() {
  # 1. Visual shift (if using P10K, we could set a flag; for now, we print a warning)
  printf "\n\033[1;33m(!)\033[0m \033[1mCalm Mode Active\033[0m: High error velocity detected.\n" >&2
  printf "    Would you like me to summarize the recent logs for you? (zdots-ctx triage)\n\n" >&2

  # 2. Automatically generate a log triage summary in the background
  (
    local trace_file="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/traces.jsonl"
    if [[ -f "$trace_file" ]]; then
      local last_errors
      last_trace_id=$(tail -n 1 "$trace_file" | jq -r '.sid' 2>/dev/null)
      
      # Just offer a quick tip based on the very last error
      local last_error_msg
      last_error_msg=$(tail -n 50 "$trace_file" | grep "\"status\":{\"code\":2}" | tail -n 1 | jq -r '.name' 2>/dev/null)
      
      if [[ -n "$last_error_msg" ]]; then
        printf "    \033[1;34mTip\033[0m: Your last error was in '\033[1m%s\033[0m'.\n" "$last_error_msg" >&2
      fi
    fi
  ) &!
}
