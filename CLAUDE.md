# CLAUDE.md

Claude-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, and **RTK token-optimization rules**.

## Platform Control

`zdots-ctl` is the single command to manage the entire local platform. Use it exclusively for service orchestration — do not call `local-ci`, `otel-collector`, or `llama-ctl` start/stop directly unless operating on a specific service in isolation.

```bash
zdots-ctl check        # deep health diagnostic (run first when something is wrong)
zdots-ctl status       # live status of all services
zdots-ctl up           # start everything in dependency order
zdots-ctl down         # stop everything cleanly
zdots-ctl reset        # full restart
zdots-ctl install      # first-time setup on a new workstation
```

## Database Architecture

| Attribute | Value |
|---|---|
| Database | `my` (PostgreSQL) |
| Schema owner | `zdots-brain` via Sequel migrations in `db/migrations/` |
| Consumer | `context-engine` (Rails) — read/write via `zdots_bridge.rb` |
| Migration command | `zdots-ctx migrate` |
| Migration table | `zdots_schema_migrations` |

The authoritative migrations are:
- `db/migrations/20260514000000_baseline.rb` — tables, indexes, extensions
- `db/migrations/20260515000000_add_job_functions.rb` — PL/pgSQL job functions

The old SQL files in `etc/db/migrations/` (001–009) are archived and must not be applied. Do **not** reference the `zdots` database — that is an unrelated legacy app schema.

## Claude Context
- This environment is optimized for `claude-code` via the `cl` alias.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#rtk-rust-token-killer---history-aware-optimizations) for all high-output commands.
- Use `repomix` to ingest the entire project structure if high-density context is required.
