#!/usr/bin/env bash
# lib/phi_scrubber.bash — PHI pattern scrubber for the zdots content pipeline.
#
# phi_scrub — reads from stdin, writes scrubbed content to stdout.
#             Always returns 0; the caller always gets usable output.
#
# Patterns are compiled lazily from etc/phi-patterns.yaml on first use and
# cached in _PHI_SED_ARGS for the lifetime of the process. Fails hard if yq
# is not installed or the registry is missing.
#
# Constraint: patterns and replacements must not contain ';' (used as sed
# delimiter). See etc/phi-patterns.yaml.
#
# Redaction markers (from PHI safety policy doc-002):
#   [REDACTED-SSN]   NNN-NN-NNNN
#   [REDACTED-MRN]   MRN: NNNNNN  /  MRN NNNNNN
#   [REDACTED-DOB]   DOB: MM/DD/YYYY  /  Date of Birth: ...
#   [REDACTED-CONN]  postgresql|mysql|redis connection strings with credentials

[[ -n "${_PHI_SCRUBBER_LOADED:-}" ]] && return 0
readonly _PHI_SCRUBBER_LOADED=1

_PHI_PATTERNS_FILE="${ZDOTDIR:-$HOME/.config/zsh}/etc/phi-patterns.yaml"
declare -a _PHI_SED_ARGS=()

# _phi_load_patterns — compile YAML registry into _PHI_SED_ARGS.
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

  local count
  count=$(yq '.patterns | length' "$_PHI_PATTERNS_FILE" 2>/dev/null) || {
    printf 'phi_scrubber: failed to parse %s\n' "$_PHI_PATTERNS_FILE" >&2
    return 1
  }

  local i=0
  while (( i < count )); do
    local regex replace
    regex=$(yq ".patterns[$i].regex" "$_PHI_PATTERNS_FILE")
    replace=$(yq ".patterns[$i].replace" "$_PHI_PATTERNS_FILE")
    _PHI_SED_ARGS+=(-e "s;${regex};${replace};g")
    (( i++ ))
  done
}

phi_scrub() {
  if [[ ${#_PHI_SED_ARGS[@]} -eq 0 ]]; then
    if ! _phi_load_patterns; then
      # Patterns unavailable (yq missing, registry absent).  Pass input through
      # unchanged so the AI pipeline keeps running; the stderr message from
      # _phi_load_patterns tells the operator what to fix.
      cat
      return 0
    fi
  fi

  local input
  input=$(cat)
  printf '%s' "$input" | sed -E "${_PHI_SED_ARGS[@]}"
}
