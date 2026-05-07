# Configuration Reference

Zdots uses a hierarchical configuration system.

## 1. Environment Variables

### Core Variables (`.zshenv` / `env.sh`)

| Variable | Default | Purpose |
|---|---|---|
| `ZDOTDIR` | `~/.config/zsh` | Root of the Zsh configuration. |
| `XDG_DATA_HOME` | `~/.local/share` | Data storage (models, etc). |
| `XDG_CONFIG_HOME`| `~/.config` | Tool configurations. |
| `XDG_STATE_HOME` | `~/.local/state` | Persistent state (logs, history). |

### Service Manifest (`.zdots.env`)

This file defines which implementation (provider) is used for each system service.

| Variable | Values |
|---|---|
| `ZDOTS_SERVICE_AI` | `llama-cpp`, `remote`, `none` |
| `ZDOTS_SERVICE_TRACE` | `otlp`, `local`, `none` |
| `ZDOTS_SERVICE_NODE` | `mise`, `system` |
| `ZDOTS_SERVICE_PKG` | `homebrew`, `none` |

## 2. Structured Configuration (YAML)

### AI Models (`etc/ai-models.yaml`)
Defines the `llama-server` startup flags and model profiles.

### OTel Collector (`etc/otel-collector.yaml`)
Defines the telemetry pipeline (receivers, processors, exporters).

### LGTM Stack (`etc/docker-compose.lgtm.yaml`)
Docker Compose configuration for the observability hub.

## 3. Secrets

**NEVER commit secrets.**

- **`.zdots.secrets`**: Local-only file for API keys (e.g., `HUGGINGFACE_TOKEN`).
- **`.zdots.secrets.example`**: Template for required secrets.

## 4. Hardware Overrides

If running on hardware with limited RAM (e.g., 8GB), override the AI profile in `.zdots.env`:
```sh
ZDOTS_AI_PROFILE=constrained
```
Then run `llama-ctl install`.
