# Zdots — System Description for AI Assistants

**Purpose:** Drop this document into any large-context AI session (ChatGPT, Gemini, Claude, etc.) to give the assistant a complete, accurate mental model of the zdots system. It is written for fidelity, not brevity — every section matters.

---

## What Is Zdots?

Zdots ("Zsh Dots") is a personal, modular Zsh shell configuration and local developer platform for macOS Apple Silicon. It is not a framework or a plugin manager. It is an **observable control plane** — a fully instrumented, self-describing environment that manages local services, AI inference, observability, secrets, databases, and developer tooling through a unified, composable CLI surface.

The repository lives at `~/.config/zsh/` and is tracked in git. The operator (the human user, Mike Hall) is the single owner and author. AI agents (Claude Code, Pi, Aider) are **tenants** of the platform, not maintainers. Agents use the platform's CLI surface; they never patch the infrastructure without operator instruction.

### Design Philosophy

- **Observable:** Every service emits OpenTelemetry spans. Every shell command is logged (with PHI scrubbing). Every AI invocation is metered. The system can explain its own state.
- **Composable:** Services are registered in a single catalog (`lib/svc-registry.bash`). Tools are discovered via the knowledge base (`zdots-ctx hydrate tooling-catalog`). Configuration is injected through providers (SOLID dependency inversion).
- **Local-first:** AI inference runs on a local llama.cpp server. No cloud API keys are required by default. PHI-adjacent workloads never leave the machine unless explicitly authorized.
- **Self-healing:** The `/zdots-heal` skill (Claude Code) runs five sequential gates (Foundation → Colima → Services → Deep check → Knowledge base), remediates safe issues automatically, and surfaces operator-required actions as filed backlog issues.

---

## Physical Layout

```
~/.config/zsh/                  ← ZDOTDIR (the repo root)
├── .zdots.env                  ← environment manifest (machine-specific, gitignored)
├── .zdots.local                ← local overrides (gitignored)
├── .zdots.secrets              ← secret env vars (gitignored, AI CANNOT READ)
├── env.sh                      ← bootstrap: XDG, PATH construction, providers
├── .zshrc                      ← entry point: sources env.sh + conf.d/
├── conf.d/                     ← 22 numbered modules loaded by .zshrc
│   ├── 05-observability.zsh    ← OTel session instrumentation
│   ├── 08-local-bin.zsh        ← ./bin in PATH when a project has one
│   ├── 10-homebrew.zsh         ← Homebrew integration
│   ├── 30-env.zsh              ← env vars, colors, history
│   ├── 80-aliases.zsh          ← shell aliases
│   └── ...
├── lib/                        ← 17 bash libraries, sourced by bin/ scripts
│   ├── svc-registry.bash       ← SINGLE SOURCE OF TRUTH for service catalog
│   ├── phi_scrubber.bash       ← PHI/credential scrubbing before AI calls
│   ├── ai_boundary.bash        ← locality enforcement (local vs cloud AI)
│   └── ...
├── bin/                        ← 82 executable commands, always on PATH
├── providers/                  ← 17 DI providers (pkg, node, python, ai, trace)
├── functions/enabled/          ← Zsh completion functions (_zsvc, _zsynod, etc.)
├── share/man/man1/             ← man pages for user-facing commands
├── etc/                        ← config files (ai-models.yaml, phi-patterns.yaml)
├── db/migrations/              ← Sequel migrations for the `my` PostgreSQL DB
├── zsynod/                     ← AI deliberation forum (ledger, members, minutes)
├── docs/                       ← architecture docs, guides, wiki
├── backlog/                    ← task management (backlog CLI, tasks/, docs/)
├── tests/                      ← bats test suite
└── .claude/                    ← Claude Code config (settings.json, skills, hooks)
```

---

## Service Architecture

### The Service Registry

All managed services are declared in `lib/svc-registry.bash` using a single `_svc_reg` function call per service. This file is the single source of truth for:
- Service name, display name, launchd label
- Log file path
- Control script name (maps to `bin/<ctl>`)
- Health endpoint
- Service type (`launchd`, `plist`, `colima`, `nginx`, `derived`)
- Lifecycle commands (install, start, stop, restart, status, health, logs, validate)
- Aliases (e.g., `ai` → `llama`, `vm` → `colima`)

Both `bin/zsvc` (per-service control) and `bin/zdots-ctl` (full-platform orchestration) derive from this registry. No service metadata is duplicated.

### Managed Services

| Service | Label | Log | Endpoint |
|---------|-------|-----|----------|
| `llama` | com.zdots.llama-server | `~/.local/state/zsh/llama-server.log` | http://127.0.0.1:11500 |
| `embed` | com.zdots.llama-embed | `~/.local/state/zsh/llama-embed.log` | http://127.0.0.1:11501 |
| `otel` | com.zdots.otel-collector | `~/.local/state/zsh/otel-collector.log` | http://127.0.0.1:4318 |
| `o2` | com.zdots.openobserve | `~/.local/state/zsh/openobserve.log` | http://127.0.0.1:5080 |
| `colima` | com.zdots.colima-autostart | `~/.local/state/zsh/colima-autostart.log` | (VM) |
| `nginx` | homebrew.mxcl.nginx | `/opt/homebrew/var/log/nginx/error.log` | https://my.local |
| `postgres` | homebrew.mxcl.postgresql@18 | `/opt/homebrew/var/log/postgresql@18.log` | :5432 |
| `redis` | homebrew.mxcl.redis | `/opt/homebrew/var/log/redis.log` | :6379 |
| `worker` | com.zdots.worker | `~/.local/state/zsh/zdots-worker.log` | jobs queue |

All services run as macOS LaunchAgents in the user domain (`gui/<uid>/`). Nginx runs as a system LaunchDaemon. PostgreSQL and Redis are Homebrew plist services. Colima is a VM managed via its own CLI plus a zdots autostart wrapper.

### Service Control Interface

```bash
zsvc list                  # table: state, pid, endpoint for all services
zsvc start  <svc>          # start a service
zsvc stop   <svc>          # stop a service
zsvc restart <svc>         # restart a service
zsvc status <svc>          # detailed status from the service's ctl script
zsvc health                # liveness probe for all services + nginx .local URLs
zsvc health --json         # same, machine-readable
zsvc logs   <svc>          # tail the service log
zsvc diag   <svc>          # status + health + launchd state + last 50 log lines
log-rotate  <svc>          # compress + truncate service log in-place (safe with open FDs)
log-rotate  <svc> --dry-run  # preview size/path without rotating

zdots-ctl up               # start all in dependency order
zdots-ctl down             # stop all cleanly
zdots-ctl reset            # down + up
zdots-ctl check            # deep diagnostic (FileVault, SIP, AI mode, schema...)
zdots-ctl status --json    # machine-readable aggregate status
```

---

## Colima / Docker

### The Socket Problem

Colima (the macOS VM runtime for Docker) moved its Unix socket from `~/.colima/<profile>/docker.sock` to `~/.config/colima/<profile>/docker.sock` in recent versions. Scripts that hardcode the old path silently miss the running socket and report Docker as unavailable. This caused significant token waste as AI agents looped on false negatives.

### The Solution: `colima-status`

`bin/colima-status` is the authoritative interface. **Never call `colima status` directly or search for the socket manually.** Always use:

```bash
colima-status --json           # full machine-readable status blob
colima-status socket           # prints the live socket path; exit 1 if missing
colima-status health           # exit 0 = running + socket present; exit 1 = unhealthy
colima-status logs             # tail the autostart log
colima-status status           # human-readable

# Set DOCKER_HOST for any docker call:
export DOCKER_HOST="unix://$(colima-status socket)"
# or inline:
DOCKER_HOST=$(colima-status socket) docker ps
```

The JSON output schema:
```json
{
  "profile": "default",
  "running": true,
  "healthy": true,
  "socket": "/Users/mike/.config/colima/default/docker.sock",
  "socket_exists": true,
  "docker_reachable": true,
  "docker_host": "unix:///Users/mike/.config/colima/default/docker.sock",
  "runtime": "docker",
  "arch": "aarch64",
  "vm_type": "macOS Virtualization.Framework",
  "autostart_log": "~/.local/state/zsh/colima-autostart.log",
  "manage": { "start": "zsvc start colima", ... }
}
```

The guard: if the socket is found at the legacy path (`~/.colima/`) rather than the XDG path, `colima-status` emits a loud warning to stderr and logs it. The `colima-autostart` script similarly warns when it falls back to the legacy location.

---

## AI Stack

### Architecture

All AI runs locally by default (`ZDOTS_AI_MODE=local`). The platform enforces this through `lib/ai_boundary.bash`, which exits non-zero if the configured endpoint is not loopback/RFC-1918 in local mode.

```
Shell / agent
    ↓
ai_boundary.bash (locality check)
    ↓
phi_scrubber.bash (PHI/credential scrubbing)
    ↓
llama.cpp server (http://127.0.0.1:11500, OpenAI-compatible API)
    ↓ (embeddings)
embed server (http://127.0.0.1:11501, nomic-embed-text)
```

### Models

Active profile: `qwen3-8b`. Model: `Qwen_Qwen3-8B-Q4_K_M.gguf`. Profiles defined in `etc/ai-models.yaml`. The operator selects the active profile; the model file is downloaded via `llama-ctl model-download`.

Hardware: Apple M4 MBA, 16GB RAM, 256GB disk. One GGUF active at a time.

### AI Tool Matrix

| Tool | Command | Role |
|------|---------|------|
| Claude Code | `cl` / `cc` | Architecture, review, multi-file reasoning, this system |
| Pi (Ollama/llama.cpp) | `zpi` | Interactive exploration, read/explain/plan (local) |
| Aider → llama.cpp | `zaider` | File editing, implementation, git commits (local) |
| Low-priority Aider | `laid` | Background edits (nice +19, reduced threads) |
| Script inference | `ai-query` | Pipe any command output through the local model |
| Domain routing | `zdots-ask` | PHI-safe prompt router with domain detection |
| Capability probe | `zdots-quiz` | 14-case probe of local model capability |

### Claude Code Integration

Claude Code (`cl`) is a cloud tool — it bypasses the local `phi_scrub`/`ai_boundary` pipeline. The deny-list in `.claude/settings.json` and the `cc-hook-guard` pre-tool hook are the guardrails that keep secrets, keys, and PHI out of cloud prompts.

The Claude Code harness includes:
- `bin/cc-hook-guard` — PreToolUse: blocks commands matching the PHI/secret deny list
- `bin/cc-hook-lint` — PostToolUse: runs shellcheck on edited shell files (severity=warning, skips .zsh)
- `bin/cc-hook-session` — SessionStart: emits the zdots brief (service state, KB counts, AI status)
- `bin/cc-statusline` — Live status line showing service health, git state, pending jobs
- `bin/cc-doctor` — Health audit for the Claude Code integration itself

MCP servers registered in `.mcp.json`:
- `llama` → `bin/llama-mcp` (tools: llama_capabilities, llama_health, llama_config, llama_run_test, llama_integration_snippet)
- `ctx` → `bin/ctx-mcp` (tools: ctx_status, ctx_query, ctx_hydrate, ctx_add_methodology, ctx_add_lesson, ctx_capture, ctx_enqueue, ctx_jobs)
- `backlog` → backlog CLI MCP server

---

## Knowledge Base (The Second Brain)

### Architecture

The knowledge base is a PostgreSQL database (`my`, schema owner `zdots-brain`) with a Rails context engine (`zdots-ctx`), a background job worker (`zdots-worker`), and a Redis-backed embedding pipeline using nomic-embed-text-v2.

```
zdots-ctx CLI  ←→  context-engine (Rails)  ←→  my (PostgreSQL)
                           ↓
                   zdots-worker (job queue)
                           ↓
                   embed server (nomic embeddings)
                           ↓
                   pgvector (semantic search)
```

### Record Types

- **Methodologies** (`zdots-ctx add-methodology <slug> <title> <content> [tags...]`): Preferred patterns, tool recipes, architectural decisions. Indexed by slug, title, tags, and embedding. Current count: 124.
- **Lessons** (`zdots-ctx add-lesson <what> <context> [tags...]`): Session residue, one-time learnings. Current count: 112.

### Query Interface

```bash
zdots-ctx query <term>                  # full-text search
zdots-ctx query --semantic "phrase"     # embedding-based semantic search
zdots-ctx hydrate [tag]                 # context blob: methodologies matching tag
zdots-ctx hydrate tooling-catalog       # platform command catalog + scenarios
zdots-ctx status --json                 # connection health, record counts, pending jobs
```

### Platform Command Catalog

The tooling catalog is maintained by `bin/zdots-index-tools`, which:
1. Computes the git tree hash of `bin/` to detect changes
2. Runs `--help` on every executable in `bin/`
3. Upserts `tooling:<name>` methodologies (one per command, full help text)
4. Upserts `tooling:catalog` (compact one-liner index of all 82 commands)
5. Upserts `tooling:scenarios` (task-to-tool recipes covering common agent workflows)
6. Records state in `~/.local/state/zsh/zdots-index-tools.state` (hash + timestamp, 7-day TTL)
7. Runs daily at 04:00 via a LaunchAgent and as phase 14 of `zdots-update-local`

**Agents should always call `zdots-ctx hydrate tooling-catalog` at task start** to get the current platform tool inventory. This eliminates the failure mode where an agent invents or imports an external tool that zdots already provides.

---

## Database Architecture

| Attribute | Value |
|-----------|-------|
| Database | `my` (PostgreSQL 18) |
| Schema owner | `zdots-brain` via Sequel migrations in `db/migrations/` |
| Migration user | OS user (superuser) via `ZDOTS_MIGRATION_URL` |
| App user | `zdots_rw` — write access via `zdots-ctx` only |
| Read-only | `zdots_ro` — SELECT only, safe for ad-hoc queries |
| Auth | `scram-sha-256` (enforced via `pg_hba.conf`) |
| Migration command | `zdots-ctx migrate` |
| Exploration | `PGPASSWORD=$(zdots-keychain get ZDOTS_RO_PASSWORD) psql -U zdots_ro my` |

**Do not use the `zdots` database** — that is an unrelated legacy application schema. Always use `my`.

The authoritative migrations:
- `db/migrations/20260514000000_baseline.rb` — tables, indexes, pgvector, extensions
- `db/migrations/20260515000000_add_job_functions.rb` — PL/pgSQL job functions
- `db/migrations/20260522000000_setup_access_roles.rb` — zdots_ro/zdots_rw roles

---

## Observability Stack

### Architecture

```
Any process (OTel SDK)
    ↓ OTLP HTTP :4318 or gRPC :4317
otelcol-contrib (native binary, com.zdots.otel-collector)
    ↓
OpenObserve (native binary, com.zdots.openobserve, :5080)
    UI: http://o2.local (nginx reverse proxy)
```

All three (OTLP endpoint, collector, OpenObserve) run as native macOS processes — no Docker dependency. The LGTM stack (Grafana/Loki/Tempo/Prometheus in Docker) was deprecated in favor of this native stack (task Z-134, completed).

### Instrumenting an App

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_SERVICE_NAME="my-app"
```

### PHI Audit Logging

PHI-adjacent operations emit to macOS Unified Logging:
```bash
log show --predicate 'subsystem == "com.zdots" AND category == "phi-boundary"' --last 1h
```
This survives OTel being down and cannot be cleared without root.

---

## Secrets Management

All secrets live in macOS Keychain under `service=zdots`, `account=VARNAME`. The zdots convention:

```bash
zdots-keychain get  VARNAME          # retrieve
zdots-keychain add  VARNAME value    # store
```

Underlying macOS call: `security find-generic-password -s zdots -a VARNAME -w`

**Never hardcode secrets in `.zdots.local`, `.zdots.secrets`, or any committed file.** The cc-hook-guard deny list and `.claude/settings.json` deny rules block Claude Code from reading secret files.

Credential rotation: `zdots-ctx rotate-creds` rotates `zdots_rw` and `zdots_ro` PostgreSQL passwords and stores new ones in Keychain.

---

## PHI Operating Mode (Non-Negotiable on Work Machines)

This system operates near protected health information (PHI). The following rules are enforced at the infrastructure level:

1. `ZDOTS_AI_MODE=local` is the default. Never change to `cloud` without explicit security review.
2. `ZDOTS_CAPTURE_ENABLED=0` until `ZDOTS_DB_ENCRYPTION_KEY` is provisioned in Keychain and DB encryption is verified.
3. `ZDOTS_CMD_ANALYTICS=0` on work machines — enforced by `.zdots.work`.
4. All AI calls pass through `lib/phi_scrubber.bash` (first gate, not last).
5. All shell commands pass through `_zca_redact` (suppress + scrub) before analytics storage. Connection strings are dropped entirely.
6. `lib/ai_boundary.bash` enforces locality — exits if endpoint is not loopback/RFC-1918 in local mode.
7. PHI patterns are defined exclusively in `etc/phi-patterns.yaml`. The registry auto-compiles at shell startup and applies to all layers.

Claude Code is a cloud tool and bypasses `phi_scrub`/`ai_boundary`. The deny-list in `.claude/settings.json` and `cc-hook-guard` are the cloud-specific guardrails.

---

## PATH and Local Bin

The shell PATH is constructed in `env.sh` (section 9) using a `_zdots_path_add` helper that prepends directories in precedence order:

1. `/usr/bin:/bin:/usr/sbin:/sbin` (base)
2. Homebrew (`/opt/homebrew/bin`, `/opt/homebrew/sbin`, language opt overrides)
3. Cargo, Go, PNPM, Bun, LM Studio bins
4. Homebrew provider paths (`zdots_pkg_manager_paths`)
5. `~/.config/zsh/bin` — **always on PATH** (zdots commands work from any directory)
6. `~/.local/bin`, `~/bin`

Additionally, `conf.d/08-local-bin.zsh` adds a `chpwd` hook: when you enter a directory that has a `bin/` subdirectory, that `bin/` is prepended to PATH. When you leave the directory, it is removed. This means project commands run without the `./bin/` prefix in any project directory.

---

## Zsynod — The AI Deliberation Forum

Zsynod is the multi-agent consensus system: a hash-chained, append-only ledger of proposals, votes, quorum commits, and handoffs. It enables durable handoffs between AI sessions, ratchet-style work loops, and operator-governed decision making.

### Participants (Seats)

| Handle | Role | Backend |
|--------|------|---------|
| `@secretary` | Chair, minutes, auto-pilot timer | Claude (Anthropic SDK) |
| `@hf` | Hugging Face specialist | Claude |
| `@openrouter` | OpenRouter routing specialist | Claude |
| `@aider` | Aider/implementation specialist | llama.cpp (local) |
| `@pi` | Pi/exploration specialist | llama.cpp (local) |

API keys for cloud seats are stored in Keychain (`security find-generic-password -s zdots -a HF_TOKEN -w`, etc.) — never in plaintext files. This was formalized as decision D-014 after a security incident where HuggingFace and OpenRouter keys were stored in `~/.config/zsh/tmp/*.txt`.

### Ledger

The ledger is stored in `zsynod/ledger.jsonl` — one JSON object per line, hash-chained using SHA-256 of the previous entry. Every entry includes: entry ID, proposal slug, vote, rationale, timestamp, and chain hash. The ledger is immutable by convention; amendments are new entries.

### Interface

```bash
zsynod status              # current round, chair, open proposals
zsynod tick                # one deliberation turn (secretary invokes all seats)
zsynod ui                  # full-screen Textual TUI cockpit
zsynod keys                # audit seat API keys (Keychain presence)
zsynod petition            # file a new proposal
zsynod receipt             # mark a proposal as received/acted-on
zsynod minutes             # regenerate minutes.md human mirror
```

---

## Task and Issue Management

Tasks live in `backlog/tasks/` managed by the `backlog` CLI. Each task is a markdown file with YAML frontmatter (`id`, `title`, `status`, `priority`, `labels`, `created`, `updated`).

Agents file issues via:
```bash
zdots-issue "Short description"
zdots-issue --type request  "I need zdots to do X for task Y"
zdots-issue --type question "Does zdots support X?"
zdots-issue --high          "This is blocking me"
```

`zdots-issue` creates a tracked backlog task with the agent's trace ID attached. The operator reviews and resolves. Agents wait or work around — they do not patch zdots infrastructure themselves.

**Triage labels** (canonical):
- `agent-ready` — task is well-defined enough for an agent to execute
- `needs-info` — task requires operator clarification before proceeding
- `agent-reported` — filed by an agent (zdots-issue), awaiting operator triage

Current highest task ID: Z-145.

---

## The Zdots-First Doctrine

Before reaching for any external tool, check whether zdots already provides it:

```bash
zdots-ctx hydrate tooling-catalog     # catalog + scenarios (always run at task start)
zdots-ctx query tooling:<name>        # full --help for a specific command
zdots-ctx query --semantic "phrase"   # natural-language lookup
```

**If an agent ignores this and uses an external tool that zdots already provides, it is operating incorrectly.** The catalog contains 124 methodologies covering 82 platform commands. Every common workflow (service lifecycle, AI inference, secrets, knowledge base, testing, analytics, context reduction) has a zdots-native tool.

If zdots doesn't have it: file `zdots-issue --type request` and work around at the task level.

---

## The Schrute Test

Before every action:

> "Whenever I'm about to do something, I think: would an idiot do that? And if they would, I do not do that thing." — Dwight Schrute

Applies to:
- Modifying zdots infrastructure without operator coordination
- Proceeding without verification
- Assuming confidence equals correctness
- Any action whose blast radius exceeds the task scope

If the answer is yes — stop. File a `zdots-issue`. Ask. Do not proceed.

## Kevin's Law

> "Why waste time, say lot word when few word do trick?" — Kevin Malone

Applied to every response, comment, commit message, and issue filed. No filler, no hedging, no pleasantries. Technical terms exact. Code first.

---

## Health Checks (Quick Reference)

```bash
# Full platform
zdots-ctl check            # deep: FileVault, SIP, AI mode, schema, model provenance
zdots-doctor               # env, repo, XDG, AI tools, services, runtime
capabilities --json        # environment contract (health_errors: 0 = clean)
agent-guide --json         # all service endpoints and connection info

# Container runtime (always use this, never raw colima)
colima-status --json       # complete Docker/Colima status
colima-status health       # exit 0 = healthy

# Services
zsvc list                  # all services: state, pid, endpoint
zsvc health --json         # liveness of all + nginx .local URLs

# Knowledge base
zdots-ctx status --json    # connected, counts, pending jobs

# Self-healing
/zdots-heal                # Claude Code skill: five-gate automated diagnostic + remediation
```

---

## Key File Locations (Quick Reference)

| What | Path |
|------|------|
| Service registry | `~/.config/zsh/lib/svc-registry.bash` |
| PHI patterns | `~/.config/zsh/etc/phi-patterns.yaml` |
| AI model profiles | `~/.config/zsh/etc/ai-models.yaml` |
| OTel collector config | `~/.config/zsh/etc/otel-collector.yaml` |
| DB migrations | `~/.config/zsh/db/migrations/` |
| Zsynod ledger | `~/.config/zsh/zsynod/ledger.jsonl` |
| Zsynod members | `~/.config/zsh/zsynod/members.json` |
| Backlog tasks | `~/.config/zsh/backlog/tasks/` |
| Claude Code settings | `~/.config/zsh/.claude/settings.json` |
| Claude Code hooks | `~/.config/zsh/.claude/settings.json` → `hooks` |
| MCP servers | `~/.config/zsh/.mcp.json` |
| Claude Code skills | `~/.config/zsh/.claude/commands/` |
| State/logs | `~/.local/state/zsh/` |
| Knowledge base | PostgreSQL `my` database |
| Secrets | macOS Keychain, service=zdots |
| Colima socket | `~/.config/colima/default/docker.sock` (XDG, canonical) |
| History SQLite | `~/.local/state/zdots/history.sqlite3` |
| OTel traces JSONL | `~/.local/state/zsh/traces.jsonl` |

---

*Generated 2026-06-12. Repo: `github.com/just3ws/zdots`. Operator: Mike Hall.*
