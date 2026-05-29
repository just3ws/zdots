# Interface Inventory

Generated baseline: 2026-05-29 manual audit.

This file is the human-readable companion to `interface-inventory.json`. It tracks operator-facing commands, important flags, environment variables, live probes, and mutation risk.

## Commands

| Command | Section | Mutates | Purpose |
|---|---:|---|---|
| `capabilities` | 1 | no | Environment health and service contract validator |
| `zdots-ctx` | 1 | yes | PostgreSQL-backed knowledge layer interface |
| `zmorning` | 1 | no | Session-open orientation brief and launcher |
| `agent-guide` | 1 | no | Live service status and usage guidance for AI agents |
| `zdots-ctl` | 8 | yes | Platform orchestrator and health checker |
| `ai-query` | 1 | no | Guarded one-shot local inference |
| `zdots-ask` | 1 | no | Domain-aware local AI prompt router |
| `ztask` | 1 | yes | Task-driven environment bridge |
| `zdots-log-analyze` | 1 | no | Package deploy logs for diagnostics |

## Core Environment Variables

| Variable | Primary commands |
|---|---|
| `ZDOTDIR` | most commands |
| `ZDOTS_AI_ENDPOINT` | `capabilities`, `zmorning`, `agent-guide`, `zdots-ctl`, `ai-query`, `zdots-log-analyze` |
| `ZDOTS_AI_EMBED_ENDPOINT` | `zdots-ctl`, `zdots-log-analyze` |
| `ZDOTS_AI_MODE` | `zdots-ctx`, `zmorning`, `agent-guide`, `zdots-ctl`, `zdots-ask`, `zdots-log-analyze` |
| `ZDOTS_AI_MODEL` | `capabilities`, `agent-guide`, `ai-query` |
| `ZDOTS_AI_MODELS_DIR` | `zdots-ctl`, `llama-ctl` |
| `ZDOTS_AI_PROFILE` | `zdots-ctl`, `llama-ctl` |
| `ZDOTS_BOOT_TIMEOUT` | `zdots-ctl` |
| `ZDOTS_CAPTURE_ENABLED` | `zdots-ctx`, `zdots-ctl` |
| `ZDOTS_CMD_ANALYTICS` | `zdots-ctx` |
| `ZDOTS_CONTEXT` | `zmorning`, `zdots-ctl`, `zdots-log-analyze` |
| `ZDOTS_DATABASE_URL` | `zdots-ctx`, `agent-guide` |
| `ZDOTS_DATABASE_URL_OVERRIDE` | `zdots-ctx` |
| `ZDOTS_DB_ENCRYPTION_KEY` | `zdots-ctl` |
| `ZDOTS_DOMAINS_FILE` | `zdots-ask` |
| `ZDOTS_ENV_PROFILE` | `capabilities`, `zdots-log-analyze` |
| `ZDOTS_HISTORY_REDACT` | `zdots-ctl` |
| `ZDOTS_LOG_ANALYZE_AI_TIMEOUT` | `zdots-log-analyze` |
| `ZDOTS_LOG_DIR` | `agent-guide`, `zdots-log-analyze` |
| `ZDOTS_MIGRATION_URL` | `zdots-ctx`, `agent-guide` |
| `ZDOTS_MY_ROOT` | `zdots-ctx` |
| `ZDOTS_OTEL_RESOURCE_JSON` | `capabilities` |
| `ZDOTS_REDIS_HOST` | `zdots-ctx`, `zdots-ctl` |
| `ZDOTS_REDIS_PORT` | `zdots-ctx`, `zdots-ctl` |
| `ZDOTS_SERVICE_AI` | `capabilities` |
| `ZDOTS_SESSION_ID` | `capabilities`, `zdots-ctx` |
| `ZDOTS_SKIP_FIREWALL_CHECK` | `zdots-ctl` |
| `ZDOTS_TRACE_ID` | `capabilities` |

## Known Gaps

See `docs/generated/docs-contract-known-gaps.txt`.
