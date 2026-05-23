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

**NEVER commit secrets.** All secrets live in macOS Keychain.

- **`.zdots.secrets`**: Keychain-backed loader — calls `security find-generic-password` at shell startup. No literal values. Gitignored.
- **`.zdots.secrets.example`**: Shows the Keychain pattern. Safe to commit.

### Managing secrets

```bash
zdots-keychain add VARNAME value      # store or update
zdots-keychain get VARNAME            # retrieve
zdots-keychain list                   # list all stored names
zdots-keychain verify                 # confirm all .zdots.secrets vars resolve
```

### Required secrets

| Variable | Purpose | Generate |
|---|---|---|
| `ZDOTS_DB_ENCRYPTION_KEY` | pgcrypto key for PHI columns | `openssl rand -hex 32` |
| `HUGGINGFACE_TOKEN` | Gated model downloads | HuggingFace settings |
| `MAXMIND_ACCOUNT_ID` / `MAXMIND_LICENSE_KEY` | GeoIP database | MaxMind account |

### Agent sessions

Agent environments may not inherit the full login shell. If a tool reports `ZDOTS_DB_ENCRYPTION_KEY` is missing:
```bash
export ZDOTS_DB_ENCRYPTION_KEY=$(zdots-keychain get ZDOTS_DB_ENCRYPTION_KEY)
```

## 4. Interactive Workflow Tools

### Session ritual

```bash
zmorning          # brief (date/git/db/AI status) → drops into zdash
zmorning --brief  # status only, no launcher
zmorning --pi     # status → Pi conversational orientation
```

### zdash — task launcher

fzf-powered task picker. Keybindings:

| Key | Action |
|---|---|
| `enter` | `ztask start` — activate task environment |
| `ctrl-p` | `zpi` — explore/plan with Pi |
| `ctrl-a` | `zaider` — implement with Aider |
| `ctrl-s` | `zdots-status` — full platform health TUI |
| `ctrl-d` | `ztask done` — complete active task |
| `?` | toggle preview pane |
| `Alt-z` | open zdash from anywhere at the shell prompt |

### ZLE AI keybindings

| Key | Action |
|---|---|
| `Alt-e` | Explain current command buffer (calls local llama.cpp) |
| `Alt-f` | Suggest fix for last failed command |
| `Alt-z` | Open zdash task launcher in-place |

## 5. Hardware Overrides

If running on hardware with limited RAM (e.g., 8GB), override the AI profile in `.zdots.env`:
```sh
ZDOTS_AI_PROFILE=constrained
```
Then run `llama-ctl install`.
