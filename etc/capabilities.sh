#!/usr/bin/env bash
# etc/capabilities.sh — Zdots capability declaration
#
# Machine-readable declaration of what zdots provides to external consumers:
# - adots (during initialization)
# - Claude Code (environment introspection)
# - Other agents and tools (capability discovery)
#
# Format: Bash associative arrays with structured capability strings.
# Non-executable. Idempotent. Safe to source multiple times.
#
# Usage:
#   source /Users/mike/.config/zsh/etc/capabilities.sh
#   printf '%s\n' "${ZDOTS_CAPABILITIES[@]}"
#   echo "$ZDOTS_VERSION"
#   echo "$ZDOTS_PROFILE"

set -euo pipefail
trap '' PIPE

# Guard: skip if already loaded in this session
if [[ -n "${_ZDOTS_CAPABILITIES_LOADED:-}" ]]; then
  return 0
fi
readonly _ZDOTS_CAPABILITIES_LOADED=1

# ────────────────────────────────────────────────────────────────────────────
# Version & Identity
# ────────────────────────────────────────────────────────────────────────────

# ZDOTS_VERSION: git short hash, or "unknown" if not in a git repo
# (exported for use by sourcing scripts and external tools)
# shellcheck disable=SC2034
ZDOTS_VERSION="unknown"
if [[ -d "${ZDOTDIR:-$HOME/.config/zsh}/.git" ]]; then
  ZDOTS_VERSION="$(cd "${ZDOTDIR:-$HOME/.config/zsh}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
fi
export ZDOTS_VERSION
readonly ZDOTS_VERSION

# ZDOTS_PROFILE: machine profile (work | home | unknown)
# (exported for use by sourcing scripts and external tools)
# shellcheck disable=SC2034
ZDOTS_PROFILE="${ZDOTS_ENV_PROFILE:-unknown}"
export ZDOTS_PROFILE
readonly ZDOTS_PROFILE

# ZDOTS_DIR: canonical zdots root
# (exported for use by sourcing scripts and external tools)
# shellcheck disable=SC2034
ZDOTS_DIR="${ZDOTDIR:-$HOME/.config/zsh}"
export ZDOTS_DIR
readonly ZDOTS_DIR

# ────────────────────────────────────────────────────────────────────────────
# Knowledge Layer Operations
# ────────────────────────────────────────────────────────────────────────────
# Queries and interactions with the PostgreSQL Intelligence Suite (context-engine).
# These form the primary interface for knowledge capture, retrieval, and synthesis.

declare -ga ZDOTS_CAPABILITIES_KNOWLEDGE=(
  # Knowledge base queries
  "knowledge:query:zdots-ctx query <term>                   — Search lessons and methodologies for a term"
  "knowledge:ask:zdots-ctx ask <question>                   — Ask a natural-language question against the knowledge base"
  "knowledge:semantic:zdots-ctx query --semantic <query>    — Semantic search (vector-backed)"

  # Knowledge base administration
  "knowledge:hydrate:zdots-ctx hydrate [tag]                — Load context blob for AI tasks; optional tag filters"
  "knowledge:capture:zdots-ctx capture                      — Distill session into a lesson (traces → structured)"
  "knowledge:export-wiki:zdots-ctx export-wiki [dir]        — Export knowledge base to markdown tree"
  "knowledge:compile-wiki:zdots-ctx compile-wiki            — Recompile markdown wiki from DB"

  # Lesson/methodology management
  "knowledge:add-methodology:zdots-ctx add-methodology <slug> <title> <content> [tags...]  — Register a methodology"
  "knowledge:add-lesson:zdots-ctx add-lesson <content> [context] [tags...]                 — Create a lesson"

  # Database connection and introspection
  "knowledge:status:zdots-ctx status                        — Check database connection and schema version"
  "knowledge:init-db:zdots-ctx init-db                      — Initialize the knowledge base schema"
  "knowledge:migrate:zdots-ctx migrate                      — Apply pending SQL migrations"
  "knowledge:rotate-creds:zdots-ctx rotate-creds [role]     — Rotate database credentials (default: all roles)"
  "knowledge:backup:zdots-ctx backup                        — Create timestamped SQL dump"
  "knowledge:restore:zdots-ctx restore [file]               — Restore database from dump"
)

# ────────────────────────────────────────────────────────────────────────────
# Platform Service Operations
# ────────────────────────────────────────────────────────────────────────────
# Service lifecycle: llama (AI), embed (embeddings), otel (observability),
# colima (container runtime), nginx (reverse proxy), postgres (database), redis (cache).

declare -ga ZDOTS_CAPABILITIES_SERVICES=(
  # Service introspection
  "services:list:zsvc list                                  — Table of all services: state, pid, endpoint"
  "services:validate:zsvc validate <service>                — Validate a service's configuration"

  # Service lifecycle (unified interface)
  "services:start:zsvc start <service>                      — Start a service (any managed service)"
  "services:stop:zsvc stop <service>                        — Stop a service"
  "services:restart:zsvc restart <service>                  — Restart a service"
  "services:status:zsvc status <service>                    — Full status report (from service's ctl script)"
  "services:health:zsvc health <service>                    — Liveness probe (exit 0 if healthy)"
  "services:logs:zsvc logs <service>                        — Tail service log (Ctrl+C to stop)"
  "services:diag:zsvc diag <service>                        — Diagnostics: status + health + launchd + last 50 lines"

  # Service catalog
  "services:managed:zdots_svc_managed                       — List zsvc-controllable services (function)"
  "services:resolve:zdots_svc_resolve <alias>              — Resolve service alias to canonical name (function)"

  # Specific service operations
  "services:llama:llama-ctl                                 — Llama.cpp server control"
  "services:llama-caps:llama-caps                           — Capability probe (14-case test suite)"
  "services:openobserve:openobserve-ctl                     — OpenObserve control"
  "services:otel:otel-collector                             — OTel collector control"
  "services:nginx:nginx-ctl                                 — Nginx reverse proxy control"
)

# ────────────────────────────────────────────────────────────────────────────
# System Health & Diagnostics
# ────────────────────────────────────────────────────────────────────────────
# Environment validation, service checks, database state, observability readiness.

declare -ga ZDOTS_CAPABILITIES_HEALTH=(
  # Primary health check
  "health:doctor:zdots-doctor                               — System health check (env, repo, XDG, AI, services, runtime)"
  "health:doctor-quick:zdots-doctor --no-runtime            — Fast mode: skip zdots-ctl (quicker, minimal checks)"
  "health:doctor-quiet:zdots-doctor --quiet                 — Warnings and failures only"

  # Deep orchestration check
  "health:ctl-check:zdots-ctl check                         — Deep runtime health (services, DB, AI endpoint, PHI scrubber)"

  # Service status aggregation
  "health:ctl-status:zdots-ctl status                       — Live status of all managed services"

  # Environment capabilities (contract testing)
  "health:capabilities:capabilities                         — Environment health + service contract + path validation"
  "health:capabilities-json:capabilities --json             — Machine-readable capabilities report"

  # Container runtime
  "health:colima-status:colima-status --json                — Colima health (JSON)"
  "health:colima-health:colima-status health                — Colima health check (exit code)"
  "health:colima-socket:colima-status socket                — Get socket path (use in DOCKER_HOST=...)"
)

# ────────────────────────────────────────────────────────────────────────────
# Full Platform Orchestration
# ────────────────────────────────────────────────────────────────────────────
# Multi-service lifecycle: bring-up, teardown, reset, install.

declare -ga ZDOTS_CAPABILITIES_ORCHESTRATION=(
  # Full lifecycle
  "orchestration:up:zdots-ctl up                            — Start all services in dependency order"
  "orchestration:down:zdots-ctl down                        — Stop all services cleanly"
  "orchestration:reset:zdots-ctl reset                      — Full restart (down + up)"
  "orchestration:install:zdots-ctl install                  — First-time setup on a new workstation"
)

# ────────────────────────────────────────────────────────────────────────────
# AI & Local Inference
# ────────────────────────────────────────────────────────────────────────────
# Local LLM inference via llama.cpp (default), with optional cloud routing.

declare -ga ZDOTS_CAPABILITIES_AI=(
  # Inference interface
  "ai:query:ai-query <prompt>                               — Scripted inference (piped or direct)"
  "ai:query-piped:cmd | ai-query <task>                     — Pipe output to AI for analysis"
  "ai:ask:zdots-ask <prompt>                                — Domain-aware prompt router (local LLM)"
  "ai:ask-domain:zdots-ask --domain ruby \"...\"            — Route to domain-specific model (ruby, python, etc.)"

  # Model capability testing
  "ai:quiz:zdots-quiz                                       — 14-case capability probe (full suite)"
  "ai:quiz-quick:zdots-quiz --quick                         — 3-case probe (fast)"

  # AI endpoint configuration
  "ai:endpoint:zdots-endpoints                              — Show configured AI/embed endpoints"

  # Aider (local LLM wired to file editing)
  "ai:aider:zaider                                          — Aider wired to local llama.cpp"
  "ai:aider-low-priority:laid                               — Low-priority Aider (nice +19, reduced threads)"
)

# ────────────────────────────────────────────────────────────────────────────
# Observability & Analytics
# ────────────────────────────────────────────────────────────────────────────
# OTel tracing, metrics, command analytics, and session residue capture.

declare -ga ZDOTS_CAPABILITIES_OBSERVABILITY=(
  # Observability queries
  "observability:otel-status:zdots-ctl status               — OTel collector status"
  "observability:otel-query:zdots-o2-query                  — Query OpenObserve for logs/traces"
  "observability:trace-verify:trace-verify                  — Verify trace data (test mode)"
  "observability:otel-smoke:otel-smoke                      — Smoke test OTel collection"

  # Command analytics
  "observability:history-analyze:history-analyze            — Analyze command history (SQLite)"
  "observability:history-import:history-import              — Import shell history into analytics"
  "observability:metrics-export:zmetrics                    — Export metrics snapshot"

  # Log management
  "observability:logs:zdots-logs                            — Unified log query"
  "observability:log-analyze:zdots-log-analyze              — Analyze log patterns"
  "observability:log-rotate:log-rotate <service>            — Rotate and compress service log in-place"
)

# ────────────────────────────────────────────────────────────────────────────
# Task & Project Management
# ────────────────────────────────────────────────────────────────────────────
# Backlog-driven workflows, task tracking, work-in-progress state.

declare -ga ZDOTS_CAPABILITIES_TASKS=(
  # Task operations
  "tasks:list:backlog list                                  — List all tasks (backlog/tasks/)"
  "tasks:create:backlog create <title> [description]        — Create a new task"
  "tasks:edit:backlog edit <id>                             — Edit task content and status"
  "tasks:complete:backlog complete <id>                     — Mark task complete"
  "tasks:archive:backlog archive <id>                       — Archive completed task"

  # Zdots-specific task interface
  "tasks:start:ztask start <id>                             — Start work: hydrate context, mark in-progress"
  "tasks:stop:ztask stop <id>                               — Stop work: capture session, mark status"

  # Issue filing (tracked in backlog)
  "tasks:file-issue:zdots-issue <description>              — File a tracked zdots issue"
  "tasks:file-issue-request:zdots-issue --type request      — Request a zdots capability"
  "tasks:file-issue-question:zdots-issue --type question    — Ask zdots a question"
)

# ────────────────────────────────────────────────────────────────────────────
# Security, PHI, & Secrets
# ────────────────────────────────────────────────────────────────────────────
# PHI scrubbing, secret scanning, credential management.

declare -ga ZDOTS_CAPABILITIES_SECURITY=(
  # PHI scrubbing and redaction
  "security:phi-scrub:zdots-phi-scrub <text>               — Apply PHI Scrubber (redact protected health info)"
  "security:phi-compile:zdots-otel-phi-compile             — Compile PHI patterns from etc/phi-patterns.yaml"
  "security:phi-patterns:zdots-pattern                     — Query active PHI patterns"

  # Credential management
  "security:keychain:zdots-keychain                        — Keychain credential operations"
  "security:rotate-creds:zdots-ctx rotate-creds [role]    — Rotate database passwords"
  "security:github-keys:zdots-github-keys                  — SSH key management for GitHub"

  # Secret scanning
  "security:secret-scan:bin/secret-scan                    — Pre-commit secret scanner (gitleaks)"
)

# ────────────────────────────────────────────────────────────────────────────
# Code Analysis & Linting
# ────────────────────────────────────────────────────────────────────────────
# Ruby audit suite, code review, linting, complexity analysis.

declare -ga ZDOTS_CAPABILITIES_CODE=(
  # Ruby audit suite
  "code:ruby-audit:ruby-audit /path/to/app                 — Full audit: bundler-audit, brakeman, rubocop, reek, flog, flay"
  "code:ruby-audit-interrogate:ruby-audit ... --interrogate — Audit with interactive Pi session"
  "code:ruby-audit-batch:ruby-audit-batch                  — Batch audit multiple apps"
  "code:ruby-audit-diff:ruby-audit-diff                    — Audit diff between versions"

  # Code review
  "code:diff-review:diff-review                            — Review current diff"

  # Linting
  "code:yaml-lint:yamllint etc/phi-patterns.yaml           — Validate YAML files"
)

# ────────────────────────────────────────────────────────────────────────────
# Configuration & Setup
# ────────────────────────────────────────────────────────────────────────────
# Environment initialization, config management, bootstrapping.

declare -ga ZDOTS_CAPABILITIES_CONFIG=(
  # Configuration management
  "config:show:zdots-config                                — Show merged configuration"
  "config:status:zdots-status                              — Platform status (services, DB, AI)"
  "config:schema:zdots-schema                              — Show schema definition"

  # Bootstrapping
  "config:bootstrap:bootstrap                              — Initialize or reinitialize shell environment"
  "config:update:zdots-update-local                        — Update local configuration"

  # Environment info
  "config:check:check                                      — Quick environment check"
  "config:agent-guide:agent-guide                          — Detailed usage guide for all services"
)

# ────────────────────────────────────────────────────────────────────────────
# Utilities & Helper Tools
# ────────────────────────────────────────────────────────────────────────────
# Miscellaneous utilities: aliases, benchmarking, log inspection, git operations.

declare -ga ZDOTS_CAPABILITIES_UTILITIES=(
  # Alias and command discovery
  "util:alias-suggest:alias-suggest                        — Suggest shell aliases from command history"

  # Benchmarking
  "util:bench:bench [cmd]                                  — Microbenchmark shell functions (via hyperfine)"

  # Log inspection
  "util:diarize:diarize                                    — Daily log inspection (interactive)"
  "util:zdash:zdash                                        — Interactive shell analytics dashboard"

  # Git and GitHub
  "util:zdots-gh:zdots-gh                                  — GitHub CLI wrapper"
  "util:commit-msg:commit-msg                              — Pre-commit hook: validate message format"
  "util:patch-export:zdots-patch-export                    — Export patch to GitHub Gist"

  # Graph analysis (code dependencies)
  "util:graphify:graphify                                  — Query local code graph (symbol lookups, call paths)"
  "util:graph-audit:zdots-graph-audit                      — Audit codebase graph structure"

  # Docker utilities
  "util:colima-autostart:colima-autostart                  — Auto-start colima on shell login"
  "util:docker-reclaim:docker-reclaim                      — Reclaim disk space from Docker"

  # Index and metadata
  "util:zdots-index-tools:zdots-index-tools                — Rebuild command index"
  "util:zdots-logs:zdots-logs                              — Unified log viewer"
)

# ────────────────────────────────────────────────────────────────────────────
# Development & Integration
# ────────────────────────────────────────────────────────────────────────────
# Agent integration, MCP servers, specialized workflows.

declare -ga ZDOTS_CAPABILITIES_DEVELOPMENT=(
  # MCP server registration
  "dev:ctx-mcp-register:ctx-mcp-register                   — Register zdots-ctx as MCP server"
  "dev:llama-mcp:llama-mcp                                 — Register llama-server as MCP server"
  "dev:pi-ctx-*:pi-ctx-{query,hydrate,status,brief}       — Pi-integrated context operations"

  # Background job management (knowledge layer)
  "dev:job-enqueue:zdots-ctx enqueue <type> <payload>     — Enqueue a job for worker processing"
  "dev:job-requeue:zdots-ctx requeue <id>                 — Requeue a failed job"
  "dev:jobs:zdots-ctx jobs                                 — List pending and recent jobs"
  "dev:worker:zdots-ctx worker [--type T]                 — Run a job worker"
  "dev:job-triage:zdots-ctx triage                        — Review and resolve permanently failed jobs"
  "dev:job-clear-stale:zdots-ctx clear-stale-jobs         — Reset 'running' jobs that have timed out"
  "dev:metrics-loop:zdots-ctx metrics-loop                — Export queue depth metrics to OTel continuously"

  # Observability integration
  "dev:gemini-invoke:gemini-invoke                         — Gemini session invocation hook"
  "dev:trace-verify:trace-verify                          — Verify trace data integrity"

  # Schema and migration introspection
  "dev:ingest-prepare:zdots-ingest-prepare                — Prepare data for database ingest"
  "dev:my-sync:zdots-my-sync                              — Sync ~/my to/from remote"
)

# ────────────────────────────────────────────────────────────────────────────
# Consolidated Capability Index
# ────────────────────────────────────────────────────────────────────────────
# Master array: all capabilities in one place for easy enumeration.

declare -ga ZDOTS_CAPABILITIES=(
  "${ZDOTS_CAPABILITIES_KNOWLEDGE[@]}"
  "${ZDOTS_CAPABILITIES_SERVICES[@]}"
  "${ZDOTS_CAPABILITIES_HEALTH[@]}"
  "${ZDOTS_CAPABILITIES_ORCHESTRATION[@]}"
  "${ZDOTS_CAPABILITIES_AI[@]}"
  "${ZDOTS_CAPABILITIES_OBSERVABILITY[@]}"
  "${ZDOTS_CAPABILITIES_TASKS[@]}"
  "${ZDOTS_CAPABILITIES_SECURITY[@]}"
  "${ZDOTS_CAPABILITIES_CODE[@]}"
  "${ZDOTS_CAPABILITIES_CONFIG[@]}"
  "${ZDOTS_CAPABILITIES_UTILITIES[@]}"
  "${ZDOTS_CAPABILITIES_DEVELOPMENT[@]}"
)

# ────────────────────────────────────────────────────────────────────────────
# Capability Categories (metadata for agents)
# ────────────────────────────────────────────────────────────────────────────
# Maps categories to their array names, for agent filtering.

declare -gA ZDOTS_CAPABILITY_CATEGORIES=(
  [knowledge]="ZDOTS_CAPABILITIES_KNOWLEDGE"
  [services]="ZDOTS_CAPABILITIES_SERVICES"
  [health]="ZDOTS_CAPABILITIES_HEALTH"
  [orchestration]="ZDOTS_CAPABILITIES_ORCHESTRATION"
  [ai]="ZDOTS_CAPABILITIES_AI"
  [observability]="ZDOTS_CAPABILITIES_OBSERVABILITY"
  [tasks]="ZDOTS_CAPABILITIES_TASKS"
  [security]="ZDOTS_CAPABILITIES_SECURITY"
  [code]="ZDOTS_CAPABILITIES_CODE"
  [config]="ZDOTS_CAPABILITIES_CONFIG"
  [utilities]="ZDOTS_CAPABILITIES_UTILITIES"
  [development]="ZDOTS_CAPABILITIES_DEVELOPMENT"
)

# ────────────────────────────────────────────────────────────────────────────
# Capability Query Functions (helper methods for agents)
# ────────────────────────────────────────────────────────────────────────────

# Print capabilities in a category (human-readable)
zdots_capabilities_list() {
  local category="$1"
  local array_name="${ZDOTS_CAPABILITY_CATEGORIES[$category]:-}"

  if [[ -z "$array_name" ]]; then
    printf 'zdots_capabilities_list: unknown category: %s\n' "$category" >&2
    return 1
  fi

  local -n arr="$array_name"
  for line in "${arr[@]}"; do
    echo "$line"
  done
}

# Print all capabilities (all categories)
zdots_capabilities_list_all() {
  for line in "${ZDOTS_CAPABILITIES[@]}"; do
    echo "$line"
  done
}

# Count capabilities in a category
zdots_capabilities_count() {
  local category="$1"
  local array_name="${ZDOTS_CAPABILITY_CATEGORIES[$category]:-}"

  if [[ -z "$array_name" ]]; then
    printf 'zdots_capabilities_count: unknown category: %s\n' "$category" >&2
    return 1
  fi

  local -n arr="$array_name"
  echo "${#arr[@]}"
}

# List all available categories
zdots_capabilities_categories() {
  printf '%s\n' "${!ZDOTS_CAPABILITY_CATEGORIES[@]}" | sort
}

# ────────────────────────────────────────────────────────────────────────────
# End of declarative block — no executable side effects below this line
# ────────────────────────────────────────────────────────────────────────────
