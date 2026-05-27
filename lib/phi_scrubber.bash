#!/usr/bin/env bash
# lib/phi_scrubber.bash — PHI pattern scrubber for the zdots content pipeline.
#
# Public functions:
#   phi_scrubber_init   — compile patterns eagerly (call at shell startup).
#   phi_should_suppress — returns 0 if input matches a suppress-flagged pattern.
#   phi_scrub           — stdin → stdout; redacts sensitive patterns.
#
# phi_scrub fails hard (non-zero) if:
#   - yq is absent or the registry is missing (PHI protection unavailable)
#   - input matches a suppress-flagged pattern (connection strings)
#
# phi_should_suppress is a fast [[ =~ ]] check with no forks. Use it as a
# pre-flight in the history hook before calling phi_scrub.
#
# Patterns are compiled from etc/phi-patterns.yaml once and cached for the
# lifetime of the process. phi_scrubber_init triggers eager compilation;
# without it, compilation is lazy on first call to phi_scrub or phi_should_suppress.
#
# Redaction markers (from PHI safety policy doc-002):
#   [REDACTED-SSN]   NNN-NN-NNNN
#   [REDACTED-MRN]   MRN: NNNNNN  /  MRN NNNNNN
#   [REDACTED-DOB]   DOB: MM/DD/YYYY  /  Date of Birth: ...
#   [REDACTED]       inline key=value credentials (password=, token=, etc.)
#   [REDACTED]       flag-style credentials (--password VALUE, --token VALUE)
#
# Suppress patterns (conn_string): phi_scrub returns 1, no stdout.
#   phi_should_suppress returns 0 for these patterns.
#
# Constraint: patterns and replacements must not contain ';' (used as sed
# delimiter). See etc/phi-patterns.yaml.

[[ -n "${_PHI_SCRUBBER_LOADED:-}" ]] && return 0
readonly _PHI_SCRUBBER_LOADED=1

_PHI_PATTERNS_FILE="${ZDOTDIR:-$HOME/.config/zsh}/etc/phi-patterns.yaml"
declare -a _PHI_SED_ARGS=()
_PHI_SUPPRESS_PATTERN=""

# _phi_load_patterns — compile YAML registry into _PHI_SED_ARGS and _PHI_SUPPRESS_PATTERN.
# Fails hard on missing yq, missing registry, or parse error.
_phi_load_patterns() {
  if ! command -v yq >/dev/null 2>&1; then
    printf 'phi_scrubber: yq is required but not installed (brew install yq)\n' >&2
    return 1
  fi

  if [[ ! -f "$_PHI_PATTERNS_FILE" ]]; then
    printf 'phi_scrubber: pattern registry not found: %s\n' "$_PHI_PATTERNS_FILE" >&2
    return 1
  fi

  local regex replace suppress
  while IFS=$'\t' read -r regex replace suppress; do
    [[ -n "$regex" ]] || continue
    if [[ "$suppress" == "true" ]]; then
      if [[ -z "$_PHI_SUPPRESS_PATTERN" ]]; then
        _PHI_SUPPRESS_PATTERN="$regex"
      else
        _PHI_SUPPRESS_PATTERN="${_PHI_SUPPRESS_PATTERN}|${regex}"
      fi
    else
      _PHI_SED_ARGS+=(-e "s;${regex};${replace};g")
    fi
  done < <(yq -o tsv '.patterns[] | [.regex, .replace, (.suppress // "false")]' "$_PHI_PATTERNS_FILE" 2>/dev/null)

  if [[ ${#_PHI_SED_ARGS[@]} -eq 0 && -z "$_PHI_SUPPRESS_PATTERN" ]]; then
    printf 'phi_scrubber: failed to parse %s (no patterns loaded)\n' "$_PHI_PATTERNS_FILE" >&2
    return 1
  fi
}

# phi_scrubber_init — eagerly compile patterns at shell startup.
# Idempotent: returns immediately if patterns are already compiled.
phi_scrubber_init() {
  if [[ ${#_PHI_SED_ARGS[@]} -eq 0 && -z "$_PHI_SUPPRESS_PATTERN" ]]; then
    _phi_load_patterns
  fi
}

# phi_should_suppress — returns 0 if $1 matches any suppress-flagged pattern.
# No forks; uses bash/zsh [[ =~ ]] on the pre-compiled pattern string.
phi_should_suppress() {
  if [[ ${#_PHI_SED_ARGS[@]} -eq 0 && -z "$_PHI_SUPPRESS_PATTERN" ]]; then
    _phi_load_patterns || return 1
  fi
  [[ -n "$_PHI_SUPPRESS_PATTERN" ]] || return 1
  [[ "$1" =~ $_PHI_SUPPRESS_PATTERN ]]
}

# phi_scrub — stdin → stdout, redacting all sensitive patterns.
# Fails hard (non-zero, no stdout) if:
#   - patterns are unavailable (yq missing or registry absent)
#   - input matches a suppress-flagged pattern
phi_scrub() {
  if [[ ${#_PHI_SED_ARGS[@]} -eq 0 && -z "$_PHI_SUPPRESS_PATTERN" ]]; then
    if ! _phi_load_patterns; then
      return 1
    fi
  fi

  local input
  input=$(cat)

  if [[ -n "$_PHI_SUPPRESS_PATTERN" ]] && [[ "$input" =~ $_PHI_SUPPRESS_PATTERN ]]; then
    printf 'phi_scrubber: suppress-flagged pattern in input — refusing to process\n' >&2
    return 1
  fi

  if [[ ${#_PHI_SED_ARGS[@]} -gt 0 ]]; then
    printf '%s' "$input" | sed -E "${_PHI_SED_ARGS[@]}"
  else
    printf '%s' "$input"
  fi
}
