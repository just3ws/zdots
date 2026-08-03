#!/usr/bin/env bash
# lib/svc-map.bash — the "you are here" discovery layer for Platform Services.
#
# lib/svc-registry.bash answers "where is it and how do I control it"
# (endpoint, ctl script, probe). It says nothing about "what is this for" or
# "how do I call it" — the questions an external, non-zdots tool or AI needs
# answered before it can adopt a service. This module is a second, sparse,
# append-only table keyed by the same canonical names, read only by
# `zsvc map` — it never touches lifecycle control.
#
# Public interface:
#   zdots_svc_purpose <svc>     → one-line what-this-is-for
#   zdots_svc_api_kind <svc>    → protocol/API shape (openai-chat, sql, ...)
#   zdots_svc_auth <svc>        → auth requirement, or "none" if loopback-trusted
#   zdots_svc_health_path <svc> → health-check path/command, relative to endpoint
#   zdots_svc_example <svc>     → one runnable example call
#   zdots_svc_depends_on <svc>  → space-separated canonical names of prerequisites
#   zdots_svc_docs <svc>        → doc path with more detail, if any

[[ -n "${_SVC_MAP_LOADED:-}" ]] && return 0
readonly _SVC_MAP_LOADED=1

declare -Ag ZDOTS_SVC_PURPOSE=() ZDOTS_SVC_API_KIND=() ZDOTS_SVC_AUTH=()
declare -Ag ZDOTS_SVC_HEALTH_PATH=() ZDOTS_SVC_EXAMPLE=() ZDOTS_SVC_DEPENDS_ON=()
declare -Ag ZDOTS_SVC_DOCS=()

# _svc_map "name|purpose|api_kind|auth|health_path|example|depends_on|docs"
# Sparse and additive: any field may be empty. depends_on is a space-separated
# list of canonical service names within its field.
_svc_map() {
  local name purpose api_kind auth health_path example depends_on docs
  IFS='|' read -r name purpose api_kind auth health_path example depends_on docs <<< "$1"
  ZDOTS_SVC_PURPOSE[$name]="$purpose"
  ZDOTS_SVC_API_KIND[$name]="$api_kind"
  ZDOTS_SVC_AUTH[$name]="$auth"
  ZDOTS_SVC_HEALTH_PATH[$name]="$health_path"
  ZDOTS_SVC_EXAMPLE[$name]="$example"
  ZDOTS_SVC_DEPENDS_ON[$name]="$depends_on"
  ZDOTS_SVC_DOCS[$name]="$docs"
}

# ── The map ──────────────────────────────────────────────────────────────
_svc_map "llama|OpenAI-compatible chat completions, local inference only|openai-chat|none (loopback-trusted)|/health|curl -s http://127.0.0.1:11500/v1/chat/completions -d '{\"model\":\"local\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}'||docs/llama-cpp.md"
_svc_map "embed|Text embeddings for vector search|openai-embeddings|none (loopback-trusted)|/health|curl -s http://127.0.0.1:11501/v1/embeddings -d '{\"model\":\"local\",\"input\":\"hi\"}'||docs/llama-cpp.md"
_svc_map "otel|OTLP ingestion for traces/metrics/logs|otlp-http|none (loopback-trusted)|(health subcommand)|curl -s http://127.0.0.1:4318/v1/traces -d '{}'||docs/otel-collector-guide.md"
_svc_map "o2|Trace/log/metric storage and query UI|http+sql|root creds via openobserve-ctl creds|/healthz|curl -s http://127.0.0.1:5080/healthz||otel|docs/openobserve.md"
_svc_map "colima|Docker/container runtime VM|docker-socket|none (local user)|colima status|DOCKER_HOST=\$(colima-status socket) docker ps||"
_svc_map "nginx|TLS-terminating reverse proxy fronting the .localhost services|https|none (loopback-trusted)|/|curl -sk https://my.localhost/up|postgres redis|"
_svc_map "postgres|Knowledge-layer store — database 'my'|sql|zdots_ro (read) / zdots_rw (write) via scram-sha-256|pg_isready|psql -U zdots_ro my||docs/wiki/AI-and-Knowledge-Layer.md"
_svc_map "redis|Command-analytics cache buffer|redis|none (loopback-trusted)|PING|redis-cli -h 127.0.0.1 -p 6379 KEYS 'zdots:cmds:*'||"
_svc_map "worker|Async job queue drain for context-engine (my)|process|n/a (no network endpoint)|process alive||postgres|"
_svc_map "status|Control-plane status console — service/launchd/log health|http+html|none (loopback-trusted)|/healthz|curl -s http://127.0.0.1:11600/healthz||"
_svc_map "gemstash|RubyGems caching proxy + private gem host|http|none (loopback-trusted)|/|curl -s http://127.0.0.1:9292/||"
_svc_map "ctx|Context-engine query/hydrate surface over the knowledge layer|cli|none (local user)|zdots-ctx status|zdots-ctx query <term>|postgres|docs/wiki/AI-and-Knowledge-Layer.md"

# ── Accessors ────────────────────────────────────────────────────────────

zdots_svc_purpose()     { printf '%s' "${ZDOTS_SVC_PURPOSE[${1:-}]:-}"; }
zdots_svc_api_kind()    { printf '%s' "${ZDOTS_SVC_API_KIND[${1:-}]:-}"; }
zdots_svc_auth()        { printf '%s' "${ZDOTS_SVC_AUTH[${1:-}]:-}"; }
zdots_svc_health_path() { printf '%s' "${ZDOTS_SVC_HEALTH_PATH[${1:-}]:-}"; }
zdots_svc_example()     { printf '%s' "${ZDOTS_SVC_EXAMPLE[${1:-}]:-}"; }
zdots_svc_depends_on()  { printf '%s' "${ZDOTS_SVC_DEPENDS_ON[${1:-}]:-}"; }
zdots_svc_docs()        { printf '%s' "${ZDOTS_SVC_DOCS[${1:-}]:-}"; }
