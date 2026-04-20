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

A modular Zsh environment built around two ideas: **local AI inference you can actually build on**, and **a shell that observes itself**. Every command emits an OTel span. Every AI call goes through a local Qwen2.5 server with a full OpenAI-compatible API. Everything is wired together and self-describing.

This isn't a dotfiles repo — it's a local development platform.

---

## What's here

| Subsystem | What it does |
|---|---|
| **Local AI** | llama.cpp on port 8080 — chat, streaming, tool use, embeddings, Prometheus metrics. OpenAI-compatible. No cloud required. |
| **AI capability layer** | `llama-caps` and `llama-mcp` expose the full integration surface to any AI assistant — copy to clipboard, or query live as MCP tools in Claude Code. |
| **Safe inference** | `ai-query` wraps every call in guardrail layers: input normalization, heuristic scanning, trust-boundary prompt construction, bounded submission. |
| **Observability** | Every shell command → OTel span → bare-metal collector → local LGTM stack (Grafana/Loki/Tempo/Mimir) in Colima. |
| **Platform control** | `zdots-ctl` manages the entire stack — start, stop, health check, deep diagnostics — in dependency order. |
| **Provider DI** | Swap AI backends or tracing implementations by changing one env var in `.zdots.env`. |

---

## Orientation — run these first

```sh
zdots-ctl check      # deep diagnostic: tools, configs, services, AI integration, disk
agent-guide          # live service status + exact usage patterns for every service
```

Both work from any bash context — no interactive zsh needed.

---

## Building on the AI stack

The local llama.cpp server is the most important part of this setup. Here's how to get oriented fast:

```sh
# Brief any AI assistant about this stack — paste into Gemini, ChatGPT, Claude web
llama-caps --md | pbcopy

# Machine-readable capability document — use this to bootstrap integrations
llama-caps --json

# Run in Claude Code: the MCP server exposes live tools natively
# (registered in ~/.claude.json — restart Claude Code to activate)
# Tools: llama_capabilities, llama_health, llama_config, llama_run_test, llama_integration_snippet
```

The integration test suite validates the full stack end-to-end:

```sh
ruby tests/llama_integration.rb --quick   # 8 tests: health, chat, system role, embeddings
ruby tests/llama_integration.rb           # 14 tests: + streaming, tool use, cosine similarity
```

`zdots-ctl check` runs the quick suite automatically.

### Calling the API

The server alias is always `local`. Never use the GGUF filename in API calls.

```sh
# Chat
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"local","messages":[{"role":"user","content":"Hello"}]}'

# Embeddings
curl -s http://127.0.0.1:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"local","input":"text to embed"}'

# From scripts — safe, subprocess-compatible wrapper
ai-query "What does SIGPIPE mean?"
git diff | ai-query "Write a commit message"
```

### RubyLLM

```ruby
RubyLLM.configure do |c|
  c.openai_api_key         = "local"          # ignored by llama.cpp
  c.openai_api_base        = "http://127.0.0.1:8080/v1"
  c.openai_use_system_role = true
end

# REQUIRED on every call — RubyLLM has an internal model registry; "local" isn't in it
chat = RubyLLM.chat(model: "local", provider: "openai", assume_model_exists: true)
reply = chat.ask("Hello!")
```

Full snippets for Python, Node, curl, and LangChain: `llama-caps --md` or the `llama_integration_snippet` MCP tool.

### Model profiles

| Profile | Model | Size | Use |
|---|---|---|---|
| `standard` | Qwen2.5-Coder-7B-Instruct Q4_K_M | ~4.7 GB | Default — coding, shell, tool use |
| `reasoning` | Qwen2.5-7B-Instruct Q4_K_M | ~4.7 GB | General reasoning |
| `constrained` | Qwen2.5-Coder-1.5B-Instruct Q4_K_M | ~1.0 GB | Low memory / Raspberry Pi |
| `embed` | nomic-embed-text-v1.5 Q8_0 | ~274 MB | Dedicated embeddings / RAG |

Switch: `ZDOTS_AI_PROFILE=reasoning llama-ctl install`

Config source of truth: `etc/ai-models.yaml` — edit it, then run `llama-ctl install` to apply.

---

## Observability

Every shell command emits an OTel span automatically. Connect any local app with two env vars:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
```

```
Shell / ai-query / your apps
        │
        ▼  OTLP http/protobuf :4318  (gRPC :4317 also available)
  otelcol-contrib  (bare-metal host)
        │
        ▼
  LGTM stack in Colima
        ├── Grafana :3000   (admin/admin)
        ├── Loki            (logs)
        ├── Tempo           (traces)
        └── Mimir           (metrics + RED auto-derived from traces)
```

See [docs/otel-collector-guide.md](docs/otel-collector-guide.md).

---

## Installation

```sh
cd
mv -f .zshenv .zshenv.bak
git clone git@github.com:just3ws/zdots.git ~/.config/zsh
ln -s ~/.config/zsh/.zshenv ~/.zshenv
exec "$SHELL"
```

### Bootstrap

```sh
make bootstrap          # install Homebrew packages, AI stack, and ruby_llm gem
make check              # capabilities check + test suite
```

`make bootstrap` handles: Homebrew packages (including `llama.cpp`), launchd plist registration, GGUF model download (~4.7 GB), and `ruby_llm` gem install. The AI steps are non-blocking — if the model download is slow, everything else still completes.

### Local AI (first time or manual)

`make bootstrap` runs these automatically. If you need to run them manually:

```sh
llama-ctl install         # register launchd plist (llama.cpp already installed via brew)
llama-ctl model-download  # download active profile GGUF (~4.7 GB)
llama-ctl install         # re-register plist with model path; auto-starts server
llama-ctl status          # verify
ruby tests/llama_integration.rb --quick  # confirm end-to-end
```

### Claude Code MCP server (new machine)

The `llama-mcp` MCP server is registered per-machine in `~/.claude.json` (not committed to the repo). Add it manually once after bootstrap:

```json
"llama": {
  "type": "stdio",
  "command": "/Users/YOU/.config/zsh/bin/llama-mcp",
  "env": {
    "ZDOTDIR": "/Users/YOU/.config/zsh",
    "ZDOTS_AI_ENDPOINT": "http://127.0.0.1:8080",
    "PATH": "/Users/YOU/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"
  }
}
```

Then restart Claude Code. The MCP tools (`llama_capabilities`, `llama_health`, `llama_config`, `llama_run_test`, `llama_integration_snippet`) will be available natively in your session.

### Observability stack (first time)

```sh
local-ci start            # start Colima + LGTM stack
otel-collector install    # install bare-metal otelcol-contrib
otel-collector start      # start host collector
```

---

## Bin scripts

All scripts in `bin/` are standalone executables. They work from any shell — interactive or not, zsh or bash.

| Script | Purpose |
|---|---|
| `zdots-ctl` | Platform orchestrator: `up/down/reset/install/check/status` |
| `agent-guide` | Live service status + complete usage guide — run this first |
| `llama-ctl` | llama.cpp lifecycle: install, start/stop, model download, profile switching |
| `llama-caps` | Capability report: `--json` (structured), `--md` (paste to any AI) |
| `llama-mcp` | MCP server — exposes live AI tools to Claude Code (registered in `~/.claude.json`) |
| `ai-query` | Safe AI inference from any context: guardrail layers, trust-boundary wrapping |
| `capabilities` | Environment health report and provider contract validator |
| `otel-collector` | Install and manage the bare-metal `otelcol-contrib` collector |
| `local-ci` | Start/stop Colima + LGTM stack |
| `history-analyze` | Shell history: frequency reports, anomaly detection, optional AI analysis |
| `secret-scan` | High-signal secret and credential leak detector |
| `trace-verify` | OTel trace contract testing for the shell control plane |
| `bench` | Shell startup performance benchmarking |
| `docker-reclaim` | Docker/Colima disk reclaim — **dry run by default; `-f` is destructive** |
| `bootstrap` | First-time dependency installation |

---

## Configuration files

| File | Purpose |
|---|---|
| `.zdots.env` | Provider selections (`ZDOTS_SERVICE_*`), environment profile |
| `.zdots.secrets` | Private overrides (not committed; see `.zdots.secrets.example`) |
| `etc/ai-models.yaml` | llama.cpp model profiles and all server startup flags |
| `etc/otel-collector.yaml` | OpenTelemetry Collector pipeline |
| `etc/docker-compose.lgtm.yaml` | LGTM stack (Grafana, Loki, Tempo, Mimir) |

---

## Shell loading sequence

```
.zshenv → env.sh (POSIX)
    └── .zdots.env              # ZDOTS_SERVICE_* provider selections
    └── providers/              # inject _init() and path extensions per service

.zshrc → conf.d/*.zsh (numbered, circuit-breaker wrapped)
    05-observability.zsh        # OTel trace context, span helpers
    10-homebrew.zsh             # PATH, HOMEBREW_PREFIX
    20-prompt.zsh               # prompt theme
    30-env.zsh                  # XDG dirs, core exports
    40-completion.zsh           # zsh completion system
    50-options.zsh              # setopt configuration
    60-bindings.zsh             # key bindings
    70-integrations.zsh         # ai(), zoxide, direnv, atuin, fzf
    80-aliases.zsh              # aliases including ai-* and llama-ctl wrappers
    90-mise.zsh                 # mise runtime version manager
    95-ai.zsh                   # AI provider init
```

Each `conf.d/` module is wrapped in a circuit breaker — a single failure does not collapse the shell. See [docs/architecture.md](docs/architecture.md).

---

## Storage discipline

256 GB primary disk. One active GGUF at a time. Prune Docker aggressively.

```sh
llama-ctl model-df        # model storage usage (safe)
llama-ctl model-prune     # delete non-active GGUFs — confirm before running
docker-reclaim            # dry run: show what would be freed
docker-reclaim -f         # DESTRUCTIVE: prune containers/images/volumes/cache + fstrim
```

See [docs/storage-hygiene.md](docs/storage-hygiene.md).

---

## Documentation

| Doc | Contents |
|---|---|
| [AGENTS.md](AGENTS.md) | Agent standards, RTK rules, workflow |
| [docs/llama-cpp.md](docs/llama-cpp.md) | Full llama.cpp reference: commands, API, embeddings, capability discovery, metrics |
| [docs/otel-collector-guide.md](docs/otel-collector-guide.md) | OTel setup, LGTM stack, connecting local apps |
| [docs/architecture.md](docs/architecture.md) | Provider DI pattern, loading sequence, circuit breaker |
| [docs/storage-hygiene.md](docs/storage-hygiene.md) | Disk management runbook |
| [docs/startup-performance-budget.md](docs/startup-performance-budget.md) | Shell startup performance targets |
| [docs/zen.md](docs/zen.md) | Design philosophy |
| [SECURITY.md](SECURITY.md) | Security baseline: umask, argument redaction, secret scanning |
| [backlog/Backlog.md](backlog/Backlog.md) | Active tasks and architectural decisions |
