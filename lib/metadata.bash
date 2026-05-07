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

_zdots_meta_die() { printf 'metadata: error: %s\n' "$*" >&2; exit 1; }

_has_yq() { command -v yq >/dev/null 2>&1; }

# _zdots_meta_get_file <service>
_zdots_meta_get_file() {
  local service="$1"
  case "$service" in
    ai)   echo "$ZDOTS_META_DIR/ai-models.yaml" ;;
    otel) echo "$ZDOTS_META_DIR/otel-collector.yaml" ;;
    lgtm) echo "$ZDOTS_META_DIR/docker-compose.lgtm.yaml" ;;
    *)    return 1 ;;
  esac
}

# zdots_meta_resolve_yaml <service> <path>
zdots_meta_resolve_yaml() {
  local service="$1"
  local path="${2:-}"
  local file; file=$(_zdots_meta_get_file "$service")
  [[ -f "$file" ]] || return 1
  _has_yq || _zdots_meta_die "yq required"

  if [[ "$service" == "ai" ]]; then
    local profile="${ZDOTS_AI_PROFILE:-}"
    if [[ -z "$profile" || "$profile" == "null" ]]; then
      profile=$(yq ".default_profile" "$file" 2>/dev/null)
    fi

    if [[ -z "$path" ]]; then
      yq -o json ".profiles.${profile} * .server | .active_profile = \"${profile}\"" "$file" 2>/dev/null
    else
      local val; val=$(yq ".profiles.${profile}.${path}" "$file" 2>/dev/null)
      if [[ "$val" == "null" || -z "$val" ]]; then
        val=$(yq ".server.${path}" "$file" 2>/dev/null)
      fi
      echo "$val"
    fi
  elif [[ "$service" == "whisper" ]]; then
    # Unified ai-models.yaml but different top-level key
    local file; file=$(_zdots_meta_get_file ai)
    local profile="${ZDOTS_WHISPER_PROFILE:-}"
    if [[ -z "$profile" || "$profile" == "null" ]]; then
      profile=$(yq ".default_whisper_profile" "$file" 2>/dev/null)
    fi

    if [[ -z "$path" ]]; then
      yq -o json ".whisper_profiles.${profile} | .active_profile = \"${profile}\"" "$file" 2>/dev/null
    else
      yq ".whisper_profiles.${profile}.${path}" "$file" 2>/dev/null
    fi
  else
    if [[ -z "$path" ]]; then
      yq -o json "." "$file" 2>/dev/null
    else
      yq ".${path}" "$file" 2>/dev/null
    fi
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
  zdots_meta_resolve_yaml "$service" | jq -r "to_entries | .[] | \"export ${prefix}_\\(.key | ascii_upcase)=\\\"\\(.value)\\\"\""
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
