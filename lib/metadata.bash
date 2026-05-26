#!/usr/bin/env bash
# lib/metadata.bash — Unified Platform Metadata Service
#
# RATIONALE:
# Consolidates YAML configuration resolution into a single deep module.
# Handles profile merging, environment overrides, and provides a consistent
# interface for all Zdots services (AI, OTel, LGTM).
#
# DEPTH:
# - Concentrates config knowledge (Locality).
# - Provides high-leverage resolved views (--json).
# - Minimizes subshells and redundant parsing.

ZDOTS_META_DIR="${ZDOTDIR:-$HOME/.config/zsh}/etc"

# Process-level cache: keyed by "service:profile" so that profile env var
# changes invalidate correctly. Populated on first call per (service, profile)
# pair; subsequent calls use jq on the cached JSON — no yq re-parse.
declare -A _ZDOTS_META_CACHE=()

_zdots_meta_die() { printf 'metadata: error: %s\n' "$*" >&2; exit 1; }

_has_yq() { command -v yq >/dev/null 2>&1; }

# _zdots_meta_get_file <service>
_zdots_meta_get_file() {
  local service="$1"
  case "$service" in
    ai|whisper) echo "$ZDOTS_META_DIR/ai-models.yaml" ;;
    otel) echo "$ZDOTS_META_DIR/otel-collector.yaml" ;;
    lgtm) echo "$ZDOTS_META_DIR/docker-compose.lgtm.yaml" ;;
    *)    return 1 ;;
  esac
}

# _zdots_meta_resolve_profile <file> <profiles_key> <default_key> <env_var> <merge_base> <path>
#   profiles_key  — top-level yq key holding profiles map (e.g. "profiles", "whisper_profiles")
#   default_key   — yq path to the default profile name (e.g. ".default_profile")
#   env_var       — env var that overrides the active profile (e.g. ZDOTS_AI_PROFILE)
#   merge_base    — yq key merged into profile for full view, empty to skip (e.g. ".server")
#   path          — field to extract; empty returns full merged JSON
_zdots_meta_resolve_profile() {
  local file="$1" profiles_key="$2" default_key="$3" env_var="$4" merge_base="$5" path="${6:-}"

  local profile="${!env_var:-}"
  if [[ -z "$profile" || "$profile" == "null" ]]; then
    profile=$(yq "${default_key}" "$file" 2>/dev/null)
  fi

  if [[ -z "$path" ]]; then
    local expr=".${profiles_key}.${profile}"
    [[ -n "$merge_base" ]] && expr="${expr} * ${merge_base}"
    yq -o json "${expr} | .active_profile = \"${profile}\" | .endpoint = \"http://\" + .host + \":\" + (.port | tostring)" "$file" 2>/dev/null
  else
    local val; val=$(yq ".${profiles_key}.${profile}.${path}" "$file" 2>/dev/null)
    if [[ "$val" == "null" || -z "$val" ]] && [[ -n "$merge_base" ]]; then
      val=$(yq "${merge_base}.${path}" "$file" 2>/dev/null)
    fi
    echo "$val"
  fi
}

# zdots_meta_resolve_yaml <service> <path>
# Full JSON dump is cached per (service, active-profile) on first call.
# Field lookups run jq on the cache — no yq re-parse per field.
zdots_meta_resolve_yaml() {
  local service="$1"
  local path="${2:-}"

  # Cache key includes the active profile so env-var overrides invalidate correctly.
  local _ckey
  case "$service" in
    ai)      _ckey="${service}:${ZDOTS_AI_PROFILE:-}" ;;
    whisper) _ckey="${service}:${ZDOTS_WHISPER_PROFILE:-}" ;;
    *)       _ckey="$service" ;;
  esac

  if [[ -z "${_ZDOTS_META_CACHE[$_ckey]:-}" ]]; then
    local file; file=$(_zdots_meta_get_file "$service")
    [[ -f "$file" ]] || return 1
    _has_yq || _zdots_meta_die "yq required"

    local _json
    case "$service" in
      ai)
        _json=$(_zdots_meta_resolve_profile "$file" "profiles" ".default_profile" "ZDOTS_AI_PROFILE" ".server" "")
        ;;
      whisper)
        _json=$(_zdots_meta_resolve_profile "$file" "whisper_profiles" ".default_whisper_profile" "ZDOTS_WHISPER_PROFILE" "" "")
        ;;
      *)
        _json=$(yq -o json "." "$file" 2>/dev/null)
        ;;
    esac
    [[ -n "$_json" ]] || return 1
    _ZDOTS_META_CACHE[$_ckey]="$_json"
  fi

  if [[ -z "$path" ]]; then
    printf '%s\n' "${_ZDOTS_META_CACHE[$_ckey]}"
  else
    printf '%s\n' "${_ZDOTS_META_CACHE[$_ckey]}" | jq -r ".${path} // empty" 2>/dev/null
  fi
}

# zdots_meta_dump <service>
zdots_meta_dump() {
  local service="$1"
  if [[ "$service" == "platform" ]]; then
    local ai; ai=$(zdots_meta_resolve_yaml ai)
    local otel; otel=$(zdots_meta_resolve_yaml otel)
    local lgtm; lgtm=$(zdots_meta_resolve_yaml lgtm)
    printf '{"ai":%s,"otel":%s,"lgtm":%s}\n' "$ai" "$otel" "$lgtm"
  else
    zdots_meta_resolve_yaml "$service"
  fi
}

# zdots_meta_env <service>
zdots_meta_env() {
  local service="$1"
  local prefix; prefix="ZDOTS_$(echo "$service" | tr '[:lower:]' '[:upper:]')"
  zdots_meta_resolve_yaml "$service" | jq -r --arg p "${prefix}" \
    'to_entries | .[] | "export " + $p + "_" + (.key | ascii_upcase) + "=" + (.value | tostring | @sh)'
}

# Entry point for CLI usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    get) shift; zdots_meta_resolve_yaml "$@" ;;
    dump) shift; zdots_meta_dump "$@" ;;
    env) shift; zdots_meta_env "$@" ;;
    *) echo "Usage: metadata [get|dump|env] <service> [path]" >&2; exit 1 ;;
  esac
fi
