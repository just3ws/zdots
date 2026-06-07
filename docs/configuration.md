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

### Runtime, AI, and Safety Variables

These variables are used by the documented command surface. See
`docs/generated/interface-inventory.json` for the command-by-command map.

| Variable | Default | Purpose |
|---|---|---|
| `ZDOTS_CONTEXT` | `home` | Machine posture; `work` enables stricter PHI/security checks. |
| `ZDOTS_ENV_PROFILE` | detected | Capability/profile label used in reports. |
| `ZDOTS_SESSION_ID` | generated | Observable shell session id. |
| `ZDOTS_TRACE_ID` | generated | W3C trace id for the shell session. |
| `ZDOTS_AI_MODE` | `local` | AI mode: `local`, `cloud`, or `none`. |
| `ZDOTS_AI_ENDPOINT` | `http://127.0.0.1:11500` | llama.cpp chat endpoint. |
| `ZDOTS_AI_EMBED_ENDPOINT` | `http://127.0.0.1:11501` | embedding endpoint. |
| `ZDOTS_AI_MODEL` | profile-derived | Model alias passed to AI clients. |
| `ZDOTS_AI_PROFILE` | `default_profile` in YAML | Active model profile. |
| `ZDOTS_AI_MODELS_DIR` | `$XDG_DATA_HOME/llama-cpp/models` | GGUF model storage. |
| `ZDOTS_AI_MODEL_FILE` | profile-derived | Direct model file override. |
| `ZDOTS_DOMAINS_FILE` | `etc/prompts/domains.yaml` | Domain routing registry for `zdots-ask`. |
| `ZDOTS_CAPTURE_ENABLED` | `0` | Session capture gate. |
| `ZDOTS_HISTORY_REDACT` | `1` | zsh history redaction gate. |
| `ZDOTS_CMD_ANALYTICS` | `0` | Command analytics capture gate. |
| `ZDOTS_DB_ENCRYPTION_KEY` | unset | pgcrypto key for sensitive columns. |
| `ZDOTS_DATABASE_URL` | `postgresql://zdots_rw@/my` | App DB connection. |
| `ZDOTS_MIGRATION_URL` | `postgresql:///my` | Migration DB connection. |
| `ZDOTS_DATABASE_URL_OVERRIDE` | unset | Force app DB connection regardless of env sourcing. |
| `ZDOTS_MY_ROOT` | `~/my` | Identity/knowledge monorepo root. |
| `ZDOTS_REDIS_HOST` | `127.0.0.1` | Analytics Redis host. |
| `ZDOTS_REDIS_PORT` | `6379` | Analytics Redis port. |
| `ZDOTS_LOG_DIR` | `$XDG_STATE_HOME/zsh` | Deploy/update log directory. |
| `ZDOTS_LOG_ANALYZE_AI_TIMEOUT` | `90` | Default AI timeout for log analysis. |
| `ZDOTS_BOOT_TIMEOUT` | `90` | Service wait timeout for `zdots-ctl up`. |
| `ZDOTS_SKIP_FIREWALL_CHECK` | unset | Suppress Application Firewall warning in work checks. |
| `ZDOTS_CI_CPU` | `2` | Colima vCPU count for local CI. |
| `ZDOTS_CI_MEMORY` | `4` | Colima memory in GB. |
| `ZDOTS_CI_DISK` | `60` | Colima disk in GB. |
| `ZDOTS_WHISPER_PROFILE` | `standard` | Whisper profile. |
| `ZDOTS_WHISPER_MODELS_DIR` | `$XDG_DATA_HOME/whisper-cpp/models` | Whisper model storage. |
| `ZDOTS_WHISPER_MODEL_FILE` | profile-derived | Whisper model file. |
| `ZDOTS_WHISPER_HF_REPO` | unset | Whisper HuggingFace repository. |
| `ZDOTS_WHISPER_URL_PREFIX` | unset | Whisper model download prefix. |
| `AIQ_DEFAULT_MODE` | `safe-extract` | Default `ai-query` mode. |
| `AIQ_MAX_BYTES` | `32768` | Hard `ai-query` input ceiling. |
| `AIQ_WARN_BYTES` | tool default | Soft `ai-query` warning threshold. |
| `AIQ_AUDIT_LOG` | `0` | Metadata-only audit logging for `ai-query`. |

## 2. Structured Configuration (YAML)

### AI Models (`etc/ai-models.yaml`)
Defines the `llama-server` startup flags and model profiles.

### OTel Collector (`etc/otel-collector.yaml`)
Defines the telemetry pipeline (receivers, processors, exporters).

### OpenObserve
Native observability backend (logs/metrics/traces) configured in
`bin/openobserve-ctl`; no compose file. See [openobserve](openobserve.md). The
old `etc/docker-compose.lgtm.yaml` was archived when LGTM was retired (Z-134).

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
