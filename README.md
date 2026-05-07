---
id: readme
title: "Zdots: The Observable Control Plane"
purpose: Primary entry point and system overview for the Zdots environment.
links:
  - id: architecture
    rel: child
  - id: development
    rel: child
  - id: configuration
    rel: child
---

# Zdots: The Observable Control Plane

A modular Zsh environment built around two ideas: **local AI inference you can actually build on**, and **a shell that observes itself**. Every command emits an OTel span. Every AI call goes through a local Qwen server with a full OpenAI-compatible API. Everything is wired together and self-describing.

---

## 1. What's here

| Subsystem | What it does |
|---|---|
| **Local AI** | llama.cpp on port 8080. OpenAI-compatible. [docs/llama-cpp.md](docs/llama-cpp.md) |
| **Observability** | Every shell command → OTel span → LGTM stack. [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| **Safe inference** | `ai-query` wraps every call in guardrail layers. [docs/ai-query.md](docs/ai-query.md) |
| **Platform control** | `zdots-ctl` manages the entire stack in dependency order. |
| **Architecture** | Provider DI pattern for interchangeable backends. [docs/architecture.md](docs/architecture.md) |

---

## 2. Setup

Refer to [docs/development.md](docs/development.md) for full installation and bootstrapping instructions.

```sh
make bootstrap          # Install dependencies and hydrate models
zdots-ctl status        # Confirm health
```

---

## 3. Bin scripts

All scripts in `bin/` are standalone executables.

| Script | Purpose |
|---|---|
| `zdots-ctl` | Platform orchestrator: `up/down/reset/install/check/status` |
| `agent-guide` | Live service status + complete usage guide |
| `llama-ctl` | llama.cpp lifecycle and model management |
| `whisper-ctl` | Manage local whisper.cpp transcription |
| `ai-query` | Safe AI inference from any context |
| `otel-collector` | Manage the bare-metal OTel collector |
| `local-ci` | Start/stop Colima + LGTM stack |
| `secret-scan` | High-signal secret and credential leak detector |
| `bench` | Shell startup performance benchmarking |

---

## 4. Documentation Map

| Doc | Contents |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Standards, PR workflow, and rubric |
| [docs/architecture.md](docs/architecture.md) | Loading sequence, DI pattern, OTel routing |
| [docs/configuration.md](docs/configuration.md) | Env vars, YAML profiles, and secrets |
| [docs/development.md](docs/development.md) | Setup, bootstrapping, and disk hygiene |
| [docs/testing.md](docs/testing.md) | Automated tests, integration, and benchmarks |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common fixes and recovery steps |
| [docs/zen.md](docs/zen.md) | Design philosophy and Zen of Zsh |
| [docs/references.md](docs/references.md) | External bookmarks and tutorials |
| [AGENTS.md](AGENTS.md) | Agent orientation and RTK rules |
| [SECURITY.md](SECURITY.md) | Security baseline and secret scanning |
