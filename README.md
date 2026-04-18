---
id: readme
title: "Zdots: The Observable Control Plane"
purpose: Primary entry point and system overview for the Zdots environment.
links:
  - id: architecture
    rel: child
  - id: zen
    rel: child
  - id: references
    rel: child
---

# Zdots: The Observable Control Plane

Zdots is a modular Zsh environment that treats the shell as a participating node
in a local observability system. It provides local AI inference, distributed
tracing, shell history intelligence, and lifecycle management for local
services — all wired together through a provider-based dependency injection
system.

This machine serves as the **central hub for both AI inference and OTel observability**:
- **AI hub:** llama.cpp runs as a launchd service (port 8080), OpenAI-compatible API, embeddings enabled.
- **Observability hub:** bare-metal `otelcol-contrib` forwards all telemetry to a local LGTM stack in Colima.

---

## Start Here

Two commands give you a complete orientation. Run them before anything else.

```sh
# Live status of all services + copy-paste usage guide for AI and OTel
agent-guide --plain

# Environment health: validates providers, tools, disk, AI model, OTel state
capabilities --json
```

Both are in `bin/` which is on `$PATH` for every shell — interactive or not, zsh or bash.

| Command | What it tells you |
|---|---|
| `agent-guide --plain` | Which services are up/down, how to call them, what not to break |
| `capabilities --json` | Whether the environment is correctly wired and healthy |

Full agent standards and workflow: [AGENTS.md](AGENTS.md)

---

## Agent / Script Usage

> If you are an AI agent or running from a bash subprocess, run `agent-guide --plain` first.
> It will tell you the current service status and exact usage patterns. The summary below is
> a quick reference only.

**AI inference** — the `ai` zsh function is **interactive-shell-only**. Use `ai-query` instead:

```sh
# Inference from any bash context
ai-query "What does SIGPIPE mean?"
git diff | ai-query "Write a commit message"

# Direct HTTP (no tooling required)
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"local","messages":[{"role":"user","content":"Hello"}],"stream":false}'
```

**OTel / LGTM** — connect any local app:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
```

Grafana: `http://127.0.0.1:3000` (admin/admin) — available when `local-ci start` is running.

---

## Capabilities at a Glance

| Capability | Entry Point | Doc |
|---|---|---|
| **Orientation (run first)** | `agent-guide --plain`, `capabilities --json` | [AGENTS.md](AGENTS.md) |
| Local AI inference | `ai-query` (scripts), `ai` (interactive zsh), `llama-ctl` | [docs/llama-cpp.md](docs/llama-cpp.md) |
| Shell history intelligence | `history-analyze` | — |
| Distributed tracing (OTel) | automatic on every command | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| LGTM observability stack | `local-ci start` | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| Docker / Colima management | `colima-*`, `docker-reclaim` | [docs/storage-hygiene.md](docs/storage-hygiene.md) |
| Secret scanning | `secret-scan` | — |
| Startup performance | `bench` | [docs/startup-performance-budget.md](docs/startup-performance-budget.md) |
| Environment health | `capabilities` | — |

---

## Quick Start

### Installation

```sh
cd
mv -f .zshenv .zshenv.bak
git clone git@github.com:just3ws/zdots.git ~/.config/zsh
ln -s ~/.config/zsh/.zshenv ~/.zshenv
exec "$SHELL"
```

### Bootstrap

```sh
make bootstrap          # install dependencies (Homebrew packages, tooling)
make check              # run capabilities check and test suite
```

### Local AI (first time)

```sh
llama-ctl install         # brew install llama.cpp + register launchd service
llama-ctl model-download  # download active profile's GGUF (~4.7GB)
llama-ctl install         # re-register plist with model path; auto-starts server
llama-ctl status          # verify
```

### Observability stack (first time)

```sh
local-ci start               # start Colima + LGTM stack (Grafana, Loki, Tempo, Mimir)
otel-collector install    # install bare-metal otelcol-contrib binary
otel-collector start      # start host collector (forwards spans to LGTM)
```

---

## Local AI Inference

The primary local inference runtime is `llama.cpp`, managed by `bin/llama-ctl`
and configured entirely through `etc/ai-models.yaml`. The server runs as a
launchd service on port 8080, exposes an OpenAI-compatible API, and
auto-starts on login.

### Using AI

```sh
# Interactive shell (requires loaded zsh environment)
ai "What does SIGPIPE mean?"
git diff | ai "Write a commit message"
cat error.log | ai "Find the root cause"
history-analyze --ai --limit 200

# From subprocesses, scripts, or agent sandboxes (plain bash, no zsh needed)
ai-query "What does SIGPIPE mean?"
git diff | ai-query "Write a commit message"
```

> **Agent/subprocess note:** The `ai` function requires an interactive zsh session.
> Use `ai-query` or call the HTTP API directly from non-interactive contexts (scripts, CI, Claude Code's Bash
> tool).

### Model profiles (`etc/ai-models.yaml`)

| Profile | Model | Size | Use |
|---|---|---|---|
| `standard` | Qwen2.5-Coder-7B-Instruct Q4_K_M | ~4.7GB | Primary: coding, shell |
| `reasoning` | Qwen2.5-7B-Instruct Q4_K_M | ~4.7GB | General reasoning |
| `constrained` | Qwen2.5-Coder-1.5B-Instruct Q4_K_M | ~1.0GB | Low memory |
| `embed` | nomic-embed-text-v1.5 Q8_0 | ~274MB | Text embeddings / RAG |

Switch profiles: `ZDOTS_AI_PROFILE=reasoning llama-ctl install`

### Server capabilities

The managed server runs with Flash Attention, KV cache quantization (`q8_0`),
prefix cache reuse, `/v1/embeddings`, and Prometheus metrics at `/metrics`
— all configurable in `etc/ai-models.yaml`. See
[docs/llama-cpp.md](docs/llama-cpp.md) for the full reference.

---

## Observability

Every shell command emits an OTel span. Spans flow from the shell through the
bare-metal host collector to a local LGTM stack running in Colima:

```
Shell / ai-query / local apps
        |
        v OTLP (http/protobuf, port 4318)
  otelcol-contrib (host)
        |
        v forward
  LGTM stack in Colima
        |
        v
  Grafana :3000   (dashboards)
  Loki            (logs)
  Tempo           (traces)
  Mimir           (metrics)
```

Connect any local app:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
```

See [docs/otel-collector-guide.md](docs/otel-collector-guide.md).

---

## Shell Loading Sequence

```
.zshenv → env.sh (POSIX)
    └── .zdots.env          # declare ZDOTS_SERVICE_* provider selections
    └── providers/          # inject _init() and path extensions per service
        ├── ai/llama-cpp.zsh
        ├── ai/remote.zsh
        └── ai/ollama.zsh   (deprecated)

.zshrc → conf.d/*.zsh (numbered, circuit-breaker wrapped)
    05-observability.zsh    # OTel trace context, span helpers
    10-homebrew.zsh         # PATH, HOMEBREW_PREFIX
    20-prompt.zsh           # prompt theme
    30-env.zsh              # XDG dirs, core exports
    40-completion.zsh       # zsh completion system
    50-options.zsh          # setopt configuration
    60-bindings.zsh         # key bindings
    70-integrations.zsh     # ai(), zoxide, direnv, atuin, fzf, broot
    80-aliases.zsh          # all aliases including ai-* and llama-ctl wrappers
    90-mise.zsh             # mise runtime version manager
    95-ai.zsh               # AI provider init (calls zdots_ai_init)
```

Each `conf.d/` module is wrapped in a circuit breaker: a single module
failure does not collapse the shell. See
[docs/architecture.md](docs/architecture.md).

### Provider system

`ZDOTS_SERVICE_AI=llama-cpp` in `.zdots.env` selects which implementation is
loaded. Changing this value switches the entire AI subsystem without touching
any other configuration.

---

## Bin Scripts

All scripts in `bin/` are standalone executables (bash or zsh). They work
from any shell context — no interactive zsh environment required.

| Script | Purpose |
|---|---|
| `zdots-ctl` | Platform orchestrator: `up/down/reset/install/status/check` — single command to manage the full stack |
| `agent-guide` | Live service status + complete usage guidance for AI agents and scripts — run this first |
| `llama-ctl` | Full lifecycle manager for llama.cpp: install, start/stop/restart, model download, profile switching |
| `ai-query` | AI inference from any context (subprocess-safe `ai` equivalent) |
| `history-analyze` | Shell history analysis: frequency reports, anomaly detection, optional AI optimizations |
| `otel-collector` | Install and manage the bare-metal `otelcol-contrib` host collector |
| `local-ci` | Start/stop Colima + LGTM observability stack (Grafana, Loki, Tempo, Mimir) |
| `capabilities` | High-signal environment health report and contract validator |
| `check` | Bats-core test suite runner (POSIX + Zsh contracts) |
| `bench` | Shell startup performance benchmarking suite |
| `bootstrap` | First-time dependency installation |
| `secret-scan` | High-signal secret and credential leak detector |
| `trace-verify` | OTel trace contract testing for the shell control plane |
| `docker-reclaim` | Docker/Colima disk reclaim: prune images, volumes, build cache, fstrim — **dry run by default; `-f` is destructive and permanent** |
| `colima-autostart` | launchd plist registration for Colima boot persistence |
| `history-import` | Import and normalize shell history from external sources |

---

## Configuration Files

| File | Purpose |
|---|---|
| `.zdots.env` | Provider selections (`ZDOTS_SERVICE_*`), environment profile |
| `.zdots.secrets` | Private overrides (not committed; see `.zdots.secrets.example`) |
| `etc/ai-models.yaml` | llama.cpp model profiles and all server startup flags |
| `etc/otel-collector.yaml` | OpenTelemetry Collector pipeline configuration |
| `etc/docker-compose.lgtm.yaml` | LGTM stack (Grafana, Loki, Tempo, Mimir) |

---

## Storage Discipline

256GB primary disk. Keep one active GGUF model at a time. Prune Docker
aggressively. See [docs/storage-hygiene.md](docs/storage-hygiene.md).

```sh
llama-ctl model-df        # model storage usage
llama-ctl model-prune     # permanently delete non-active GGUFs — confirm before running
docker-reclaim            # dry run: show what would be freed
docker-reclaim -f         # DESTRUCTIVE: prune containers/images/volumes/cache + fstrim
```

---

## Documentation Index

| Doc | Contents |
|---|---|
| [docs/llama-cpp.md](docs/llama-cpp.md) | Complete llama.cpp + llama-ctl reference: commands, ai-models.yaml fields, API endpoints, embeddings, metrics |
| [docs/architecture.md](docs/architecture.md) | Provider DI pattern, loading sequence, circuit breaker design |
| [docs/otel-collector-guide.md](docs/otel-collector-guide.md) | OTel collector setup, LGTM stack, connecting local apps |
| [docs/storage-hygiene.md](docs/storage-hygiene.md) | Disk management runbook for Docker and LLM models |
| [docs/startup-performance-budget.md](docs/startup-performance-budget.md) | Shell startup performance targets and measurement |
| [docs/terminal-capabilities.md](docs/terminal-capabilities.md) | Terminal feature detection and configuration |
| [docs/platform-discovery.md](docs/platform-discovery.md) | Cross-platform environment detection |
| [docs/zsh-quality-rubric.md](docs/zsh-quality-rubric.md) | Quality standards for zsh code in this repo |
| [docs/zen.md](docs/zen.md) | Design philosophy |
| [docs/references.md](docs/references.md) | Zsh manuals, POSIX standards, XDG specs |
| [backlog/Backlog.md](backlog/Backlog.md) | Active tasks and architectural decisions |
| [SECURITY.md](SECURITY.md) | Security baseline: umask, argument redaction, secret scanning |
