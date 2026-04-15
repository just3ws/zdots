---
id: llama-cpp
title: "llama.cpp — Local AI Runtime"
purpose: Lifecycle management and usage guide for the llama.cpp inference server.
links:
  - id: storage-hygiene
    rel: related
  - id: readme
    rel: parent
---

# llama.cpp — Local AI Runtime

`llama.cpp` is the primary local inference runtime. All AI features in Zdots
(`ai` function, `history-analyze --ai`, `?` shell assistant) route through a
local `llama-server` binary process via its OpenAI-compatible API on port 8080.

Managed by `bin/llama-ctl`. Supervised by launchd. Configuration lives in
`etc/ai-models.yaml`. Provider wired via `ZDOTS_SERVICE_AI=llama-cpp` in
`.zdots.env`.

---

## First-Time Setup

```sh
llama-ctl install         # brew install llama.cpp + register launchd plist
llama-ctl model-download  # download active profile's GGUF from HuggingFace
llama-ctl install         # re-register plist now that model path is real
llama-ctl start           # start via launchd (auto-starts on login after this)
llama-ctl status          # verify
```

After `start`, the server runs automatically on every login. No manual restart needed.

---

## Lifecycle Commands

| Command | What it does |
|---|---|
| `llama-ctl install` | Install binary (Homebrew) + register launchd plist |
| `llama-ctl start` | Load launchd service (`RunAtLoad + KeepAlive`) |
| `llama-ctl stop` | Unload launchd service |
| `llama-ctl restart` | Stop, wait 1s, start |
| `llama-ctl status` | launchd state + health endpoint + active model |
| `llama-ctl health` | Exit 0 if server up, exit 1 if down |
| `llama-ctl logs` | `tail -f` the server log |

### Shell Aliases

```sh
ai-start    # llama-ctl start
ai-stop     # llama-ctl stop
ai-status   # llama-ctl status
ai-logs     # llama-ctl logs
```

---

## Model Management

Models are GGUF files stored in `$ZDOTS_AI_MODELS_DIR`
(default: `~/.local/share/llama-cpp/models/`).

**Storage discipline:** One active model at a time. 256GB primary disk —
stale GGUFs must be pruned.

| Command | What it does |
|---|---|
| `llama-ctl model-download` | Download active profile's GGUF from HuggingFace |
| `llama-ctl model-list` | Show downloaded GGUFs and sizes; marks active model |
| `llama-ctl model-prune` | Delete all GGUFs except the active model |
| `llama-ctl model-switch <profile>` | Print steps to switch to a different profile |
| `llama-ctl df` | Disk usage summary for model directory |

### Switching Profiles

```sh
# Example: switch to the constrained profile (1B model, ~1GB)
ZDOTS_AI_PROFILE=constrained llama-ctl model-download
# Update .zdots.env: ZDOTS_AI_PROFILE=constrained
# Re-register plist and restart:
ZDOTS_AI_PROFILE=constrained llama-ctl install
llama-ctl restart
# Prune old model:
llama-ctl model-prune
```

### External Model Storage

On a 256GB drive, keep models on an external SSD when available:

```sh
# In .zdots.env:
export ZDOTS_AI_MODELS_DIR=/Volumes/External/llama-models
```

---

## Model Profiles (`etc/ai-models.yaml`)

| Profile | Model | Size | Use |
|---|---|---|---|
| `standard` | Qwen2.5-Coder-7B-Instruct Q4_K_M | ~4.7GB | Primary: coding, shell |
| `reasoning` | Qwen2.5-7B-Instruct Q4_K_M | ~4.7GB | General reasoning |
| `constrained` | Qwen2.5-Coder-1.5B-Instruct Q4_K_M | ~1.0GB | Raspberry Pi, low memory |

All profiles use `--n-gpu-layers 99` (full Metal offload on M4).

Server defaults tuned for M4 16GB:
- `--ctx-size 32768` (standard/reasoning) — ~2GB KV cache
- `--parallel 2` — two concurrent decode slots; drop to 1 if OOM
- `--batch-size 512`

---

## AI Function

```sh
# Pipe any output into local AI
cat error.log | ai "Find root cause"
git diff | ai "Summarize changes for a commit message"

# Direct prompt
ai "What does SIGPIPE mean in a curl pipe"

# History analysis with AI
history-analyze --ai --limit 200
```

The `ai` function calls `zdots_ai_infer` from `providers/ai/llama-cpp.zsh`.
Every call emits an OTel span to the local collector (service: `zdots-shell`).

---

## Health Check

```sh
llama-ctl health && echo "up" || echo "down"
# or check the raw endpoint:
curl -sf http://127.0.0.1:8080/health
# list loaded model:
curl -sf http://127.0.0.1:8080/v1/models | jq
```

---

## Startup Behavior

The provider (`providers/ai/llama-cpp.zsh`) runs a **non-blocking** health
check at shell startup — backgrounded, never delays prompt. If the server is
down, the first explicit `ai` call fails fast with a clear message:

```
ai: llama.cpp server not responding at http://127.0.0.1:8080
    Start it with: llama-ctl start
```

---

## Update Path

```sh
upgrade-ai   # updates binary (brew upgrade llama.cpp) + re-downloads GGUF if missing
             # auto-prunes stale GGUFs to reclaim disk
```

---

## Agent Notes

- Binary not yet installed: `llama-ctl install` required before any inference.
- Model not yet downloaded: `llama-ctl model-download` required before `llama-ctl install`.
- Server must be running for `ai` function to work. Check with `llama-ctl health`.
- `ZDOTS_SERVICE_AI=llama-cpp` is the composition root — changing this in `.zdots.env` switches the entire AI subsystem.
- Never run Ollama and the llama-server binary on port 8080 simultaneously. They conflict.
- If server OOMs: reduce `--parallel` to 1 or switch to `constrained` profile.
- Log file: `~/.local/state/zsh/llama-server.log`
- Plist: `~/Library/LaunchAgents/com.zdots.llama-server.plist`
