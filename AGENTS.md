# AGENTS.md — Core Context for AI Agents

Zdots is a modular, high-performance Zsh configuration ("Observable Control Plane").

## 1. Orientation

Run these to understand the current state of the machine:
```bash
zdots-ctl status    # aggregate service status
capabilities --json  # environment contract validation
agent-guide          # detailed usage guide for all services
```

## 2. Token Optimization (RTK)

**Rule:** Always proxy high-output commands through `rtk`.

| Workflow | Patterns |
|---|---|
| **Git** | `rtk git status`, `rtk git diff`, `rtk git log` |
| **Infra** | `rtk docker logs`, `rtk fly logs` |
| **Analysis** | `rtk tokei`, `rtk summary <cmd>` |

## 3. Tool Selection

| Need | Tool |
|---|---|
| Multi-file reasoning | Claude Code (`cl`) |
| Interactive code edit | `zaider` (aider) |
| Scripted inference | `ai-query` |
| Context reduction | `rtk` |

## 4. Project Protocols

- **Tasks:** Use the `backlog` CLI. See [docs/backlog.md](docs/backlog.md).
- **Environment:** Use `ztask start <id>` when starting work to hydrate context.
- **Observability:** This is an observable session linked to the shell via `gemini-invoke`. Every tool call you make is tracked.
- **Standards:** Follow the [Zsh Quality Rubric](docs/zsh-quality-rubric.md).
- **Setup:** See [docs/migration.md](docs/migration.md) for new machine setup.
- **Testing:** See [docs/testing.md](docs/testing.md).

---

## 5. Reference

| Service | Manager | Doc |
|---|---|---|
| AI (llama.cpp) | `llama-ctl` | [docs/llama-cpp.md](docs/llama-cpp.md) |
| Transcription | `whisper-ctl` | [README.md](README.md) |
| OTel | `otel-collector` | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| LGTM Stack | `local-ci` | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| Orchestrator | `zdots-ctl` | [README.md](README.md) |
