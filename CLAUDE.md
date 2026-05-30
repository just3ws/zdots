# CLAUDE.md

Claude-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, **RTK token-optimization rules**, and **PHI Operating Mode** (Section 8 — non-negotiable on work machines).

## Platform Control

Two commands cover all service lifecycle needs:

**`zsvc`** — per-service control (start/stop/restart/logs/status/diag). Reach for this first.

```bash
zsvc list              # table of all services: state, pid, endpoint
zsvc start  <svc>      # start a service
zsvc stop   <svc>      # stop a service
zsvc restart <svc>     # restart a service
zsvc status <svc>      # full status from the service's ctl script
zsvc logs   <svc>      # tail the service log (Ctrl+C to stop)
zsvc diag   <svc>      # status + health + launchd state + last 50 log lines
# services: llama  embed  otel  colima  (aliases: ai, telemetry, vm, ...)
```

**`zdots doctor`** — system health check. Run this first when anything feels wrong.

```bash
zdots-doctor               # full check: env, repo, XDG, AI tools, services, runtime
zdots-doctor --no-runtime  # fast mode: skip zdots-ctl check (own sections only)
zdots-doctor --quiet       # warnings and failures only
```

**`zdots-ctl`** — full-platform orchestration. Use for bring-up, teardown, and diagnostics.

```bash
zdots-ctl check        # deep health diagnostic (run first when something is wrong)
zdots-ctl status       # live status of all services
zdots-ctl up           # start everything in dependency order
zdots-ctl down         # stop everything cleanly
zdots-ctl reset        # full restart
zdots-ctl install      # first-time setup on a new workstation
```

Do not call `llama-ctl`, `otel-collector`, or `local-ci` start/stop directly — use `zsvc` instead.

## Database Architecture

| Attribute | Value |
|---|---|
| Database | `my` (PostgreSQL) |
| Schema owner | `zdots-brain` via Sequel migrations in `db/migrations/` |
| Migration user | OS user (superuser) via `ZDOTS_MIGRATION_URL` |
| App user | `zdots_rw` — write access via zdots-ctx / context-engine only |
| Read-only access | `zdots_ro` — SELECT only, safe for psql exploration |
| Consumer | `context-engine` (Rails) — read/write via `zdots_bridge.rb` |
| Migration command | `zdots-ctx migrate` |
| Migration table | `zdots_schema_migrations` |

For safe psql exploration use the read-only role. `pg_hba` now enforces
`scram-sha-256` for `zdots_ro`/`zdots_rw`, so supply the password from Keychain:

```bash
PGPASSWORD="$(security find-generic-password -s zdots -a ZDOTS_RO_PASSWORD -w)" psql -U zdots_ro my
```

Passwords are ephemeral keys rotated via `zdots-ctx rotate-creds`. The OS user is
still superuser via `trust` for migrations.

The authoritative migrations are:
- `db/migrations/20260514000000_baseline.rb` — tables, indexes, extensions
- `db/migrations/20260515000000_add_job_functions.rb` — PL/pgSQL job functions
- `db/migrations/20260522000000_setup_access_roles.rb` — zdots_ro/zdots_rw roles

The old SQL files in `etc/db/migrations/` (001–009) are archived and must not be applied. Do **not** reference the `zdots` database — that is an unrelated legacy app schema.

## Code Analysis

**`ruby-audit`** — static analysis suite for any Ruby or Rails codebase, run by directory.

```bash
ruby-audit /path/to/app                          # auto-detect versions, full suite
ruby-audit /path/to/app --ruby 2.6 --rails 5.2  # override detected versions
ruby-audit /path/to/app --interrogate            # report + Pi session with context loaded
ruby-audit /path/to/app --skip flog --no-repomix # fast mode

# containerized app (no local install needed)
docker cp myapp:/app ./extracted && ruby-audit ./extracted --ruby 2.6 --rails 5.2
```

Runs: bundler-audit (CVEs), brakeman (security), rubocop (style/complexity),
reek (smells), flog (hotspots), flay (duplication). Reports land in
`~/.local/state/zsh/ruby-audits/`. See [docs/ruby-audit.md](docs/ruby-audit.md) for
architecture, the planned profile/rule-pack/backend system, and adding new version prompts.

## AI Tool Ecosystem

| Tool | Command | Role |
|------|---------|------|
| Claude Code | `cl` | Architecture, review, planning, this session |
| Pi | `zpi` | Interactive exploration, read/explain/plan |
| Aider | `zaider` | File editing, implementation, git commits |

Pi and Aider are complementary: Pi explores and plans, Aider executes and commits. See [PI.md](PI.md) and [AIDER.md](AIDER.md) for usage boundaries. Session ritual: `zmorning`.

## Claude Context
- This environment is optimized for `claude-code` via the `cl` alias.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#2-token-optimization-rtk) for all high-output commands.
- Use `repomix` to ingest the entire project structure if high-density context is required.

## Agent Skills

Engineering and productivity skills from [mattpocock/skills](https://github.com/mattpocock/skills) are installed in `.claude/commands/`. Run any with `/skill-name`.

### Issue tracker

Tasks live in `backlog/tasks/` managed by the `backlog` CLI; agent-filed issues use `zdots-issue`. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical triage roles map to backlog priorities and labels (`agent-ready`, `needs-info`, `agent-reported`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo. Primary doc is `AGENTS.md`. No `CONTEXT.md` or `docs/adr/` yet. See `docs/agents/domain.md`.
