---
id: llama-cpp
title: "llama.cpp — Local AI Runtime"
purpose: Complete reference for the llama.cpp inference server, llama-ctl interface, and ai-models.yaml configuration.
links:
  - id: storage-hygiene
    rel: related
  - id: readme
    rel: parent
---

# llama.cpp — Local AI Runtime

`llama.cpp` is the primary local inference runtime. All AI features in Zdots
(`ai` function, `history-analyze --ai`, `?` shell assistant) route through a
local `llama-server` binary via its OpenAI-compatible HTTP API on port 8080.

**Managed by** `bin/llama-ctl` — a single control script for install, lifecycle,
model management, and config.  
**Configured by** `etc/ai-models.yaml` — the single source of truth for all
server flags, model profiles, and the active default profile.  
**Supervised by** launchd (`RunAtLoad + KeepAlive`) — auto-starts on login,
restarts on crash with a 10-second throttle.  
**Wired via** `ZDOTS_SERVICE_AI=llama-cpp` in `.zdots.env`.

---

## First-Time Setup

```sh
llama-ctl install         # brew install llama.cpp; write plist (no model yet — won't start)
llama-ctl model-download  # download active profile's GGUF from HuggingFace (~4.7GB)
llama-ctl install         # re-register plist with real model path; auto-starts server
llama-ctl status          # verify
```

After the second `install`, the server runs automatically on every login.

---

## llama-ctl Command Reference

### Service Lifecycle

| Command | What it does |
|---|---|
| `llama-ctl install` | Install binary (Homebrew), write launchd plist, auto-start if model present |
| `llama-ctl start` | Load launchd service |
| `llama-ctl stop` | Unload launchd service |
| `llama-ctl restart` | Stop, wait 1s, start |
| `llama-ctl status` | launchd state + health endpoint + active model |
| `llama-ctl health` | Exit 0 if up, exit 1 if down |
| `llama-ctl logs` | `tail -f` the server log |

**`install` auto-reload behavior:** `install` unloads any running service, writes
a fresh plist from `etc/ai-models.yaml`, then loads the service — but only if
the active model file exists. If the model is missing it prints instructions
instead of starting, which would otherwise trigger a crash loop.

**Service management:**

```sh
llama-ctl start
llama-ctl stop
llama-ctl status
llama-ctl logs
```

### Model Management

| Command | What it does |
|---|---|
| `llama-ctl model-download` | Download active profile's GGUF from HuggingFace (curl, resumable) |
| `llama-ctl hydrate` | Alias for `model-download` |
| `llama-ctl model-list` | List downloaded GGUFs with sizes; marks active model |
| `llama-ctl model-switch <p>` | Print step-by-step instructions to switch to profile `<p>` |
| `llama-ctl model-prune` | Delete all GGUFs not matching the active profile |
| `llama-ctl df` | Disk usage summary for the model directory |

**Switching profiles:**

```sh
llama-ctl model-switch constrained   # prints instructions
# then follow the printed steps:
ZDOTS_AI_PROFILE=constrained llama-ctl model-download
# edit .zdots.env: export ZDOTS_AI_PROFILE=constrained
ZDOTS_AI_PROFILE=constrained llama-ctl install
llama-ctl model-prune                # reclaim disk
```

**External model storage** (recommended on 256GB primary disk):

```sh
# In .zdots.env:
export ZDOTS_AI_MODELS_DIR=/Volumes/External/llama-models
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `ZDOTS_AI_PROFILE` | `default_profile` from yaml | Active model profile |
| `ZDOTS_AI_MODELS_DIR` | `~/.local/share/llama-cpp/models` | GGUF storage root |

`ZDOTS_AI_PROFILE` overrides `default_profile` in `etc/ai-models.yaml`. When
unset, `llama-ctl` reads `default_profile` from the yaml file, so the yaml is
the single source of truth for the default.

---

## Configuration: `etc/ai-models.yaml`

All server startup flags and model profiles are defined here. After any change,
regenerate the plist and restart the server with one command:

```sh
llama-ctl install
```

### Profile Fields

Each entry under `profiles:` defines a named model configuration.

| Field | Required | Description |
|---|---|---|
| `model_file` | yes | GGUF filename on disk (under `ZDOTS_AI_MODELS_DIR`) |
| `hf_repo` | yes | HuggingFace repo slug for `model-download` |
| `size_gb` | yes | Approximate disk footprint (informational) |
| `ctx_size` | yes | `--ctx-size` passed to `llama-server` |
| `n_gpu_layers` | yes | `--n-gpu-layers`; 99 = full Metal offload on M4 |
| `description` | no | Usage guidance string |

### Profiles

| Profile | Model | Size | `ctx_size` | Use |
|---|---|---|---|---|
| `standard` | Qwen2.5-Coder-7B-Instruct Q4_K_M | ~4.7GB | 32768 | Primary: coding, shell assistant |
| `reasoning` | Qwen2.5-7B-Instruct Q4_K_M | ~4.7GB | 16384 | General reasoning |
| `constrained` | Qwen2.5-Coder-1.5B-Instruct Q4_K_M | ~1.0GB | 4096 | Low memory / Raspberry Pi |
| `embed` | nomic-embed-text-v1.5 Q8_0 | ~274MB | 2048 | Dedicated text embeddings |

### Server Fields

All fields live under `server:` and map directly to `llama-server` flags.
Fields marked **conditional** are only added to the plist when their value is
non-default (e.g. `true`, non-zero, non-empty).

| Field | Default in yaml | Flag | Conditional | Description |
|---|---|---|---|---|
| `host` | `127.0.0.1` | `--host` | no | Bind address |
| `port` | `8080` | `--port` | no | Listen port |
| `parallel` | `2` | `--parallel` | no | Concurrent decode slots; drop to 1 if OOM |
| `batch_size` | `2048` | `--batch-size` | no | Logical max tokens per scheduling cycle |
| `ubatch_size` | `512` | `--ubatch-size` | no | Physical tokens per Metal kernel dispatch |
| `cache_type_k` | `q8_0` | `--cache-type-k` | no | KV cache K dtype; q8_0 saves ~1GB vs f16 |
| `cache_type_v` | `q8_0` | `--cache-type-v` | no | KV cache V dtype |
| `cache_reuse` | `256` | `--cache-reuse` | yes (non-zero) | Min prefix length (tokens) to trigger KV reuse |
| `n_predict` | `2048` | `--predict` | yes (non -1) | Per-request generation cap; -1 = unlimited |
| `alias` | `"local"` | `--alias` | yes (non-empty) | Stable API-facing model name |
| `embeddings` | `true` | `--embeddings` | yes (true) | Enable `/v1/embeddings` endpoint |
| `pooling` | `mean` | `--pooling` | with embeddings | Token vector pooling strategy |
| `flash_attn` | `true` | `--flash-attn on` | yes (true) | Flash Attention; 2–4x KV cache reduction |
| `metrics` | `true` | `--metrics` | yes (true) | Prometheus endpoint at `/metrics` |

**`batch_size` vs `ubatch_size`:** `batch_size` (logical) is the upper bound on
tokens per scheduling cycle and must be ≥ the longest single input — embedding
requests with large RAG chunks need this ≥ input token count. `ubatch_size`
(physical) is the tokens-per-Metal-kernel-call granularity; 512 is the
llama.cpp default and works well for autoregressive decode.

**Logging:** `--log-file` is intentionally absent from the plist. The server
writes to stderr; launchd captures it via `StandardErrorPath`. Using both routes
to the same file causes double-written lines.

**Crash loop protection:** The plist includes `ThrottleInterval: 10` so launchd
waits 10 seconds between restart attempts on repeated fast exits (OOM, missing
model file, bad flag).

---

## API Endpoints

The server exposes an OpenAI-compatible API. All endpoints are on
`http://127.0.0.1:8080` by default.

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | `{"status":"ok"}` when ready; 503 while loading |
| `/v1/models` | GET | Lists loaded model; `id` reflects the configured `alias` |
| `/v1/chat/completions` | POST | OpenAI-compatible chat completions |
| `/v1/completions` | POST | OpenAI-compatible raw completions |
| `/v1/embeddings` | POST | OpenAI-compatible text embeddings |
| `/metrics` | GET | Prometheus-format metrics (prefix: `llamacpp:`) |
| `/slots` | GET | Current slot state (debug) |
| `/props` | GET | Server properties: slot count, model path, chat template |

**Model name in requests:** Always use `model: "local"` (the configured alias).
This survives profile switches — the underlying GGUF filename changes, but
`"local"` always resolves to whatever is loaded.

---

## Embeddings

The `/v1/embeddings` endpoint is enabled by default.

```sh
# Quick test — confirm dimensions
curl -sf http://127.0.0.1:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"local","input":"hello world"}' | jq '.data[0].embedding | length'

# Batch input
curl -sf http://127.0.0.1:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"local","input":["first document","second document"]}' \
  | jq '[.data[].embedding | length]'
```

**Pooling:** `mean` pools all token vectors into one fixed-length vector using
L2-normalised mean. Correct for nomic-embed and most transformer embedding
models. `cls` uses the first token; `last` uses the last.

**Chat model vs dedicated embed model:** The `standard` profile (Qwen2.5-Coder)
produces embeddings but is not trained for the task — quality is adequate for
simple use cases. The `embed` profile (`nomic-embed-text-v1.5`, 274MB) is
purpose-built and produces significantly better vectors for semantic search
and RAG.

**Running both simultaneously** (chat + dedicated embeddings):

```sh
# Start a second server on port 8081 for embeddings only
llama-server \
  --model "$ZDOTS_AI_MODELS_DIR/nomic-embed-text-v1.5.Q8_0.gguf" \
  --port 8081 --embeddings --pooling mean --n-gpu-layers 99 --ctx-size 2048

# Or switch the managed server to the embed profile
ZDOTS_AI_PROFILE=embed llama-ctl install
```

---

## Flash Attention

`--flash-attn on` is enabled by default. On Apple Silicon, this reduces KV
cache memory by 2–4x by fusing the attention computation into a single kernel
pass. Meaningfully improves throughput at longer context sizes (32K tokens).

No quality change — purely a memory and throughput optimisation.

To disable (e.g., if you observe inference anomalies):

```yaml
# etc/ai-models.yaml server:
flash_attn: false
```

Then `llama-ctl install` to apply.

---

## Metrics

Prometheus-format metrics are available at `/metrics` (enabled by default).

```sh
curl -sf http://127.0.0.1:8080/metrics | grep '^llamacpp:'
```

Key metrics (prefix: `llamacpp:`):

| Metric | Type | Description |
|---|---|---|
| `llamacpp:prompt_tokens_total` | counter | Prompt tokens processed |
| `llamacpp:tokens_predicted_total` | counter | Generation tokens produced |
| `llamacpp:prompt_seconds_total` | counter | Time spent on prompt ingestion |
| `llamacpp:n_decode_total` | counter | Total `llama_decode()` calls |
| `llamacpp:n_busy_slots_per_decode` | counter | Avg busy slots per decode call |
| `llamacpp:requests_processing` | gauge | Requests currently in flight |
| `llamacpp:requests_deferred` | gauge | Requests waiting for a free slot |

The local otelcol scrapes this endpoint and forwards to the LGTM stack.
See `docs/otel-collector-guide.md` for scrape job configuration.

---

## Provider Integration

`providers/ai/llama-cpp.zsh` is the Zdots AI provider. It:

1. Reads `etc/ai-models.yaml` at shell init to set `ZDOTS_AI_ENDPOINT` and
   `ZDOTS_AI_MODEL` — these always match what the server was started with.
2. Runs a **non-blocking** background health check at startup. Never delays
   the prompt.
3. Exposes `zdots_ai_infer PROMPT [SYSTEM]` — used by `ai`, `?`, and
   `history-analyze --ai`.

### `ai` — interactive shell function

Defined in `conf.d/70-integrations.zsh`. **Requires an interactive zsh session.**

```sh
ai "What does SIGPIPE mean in a curl pipe"
git diff | ai "Write a commit message"
cat error.log | ai "Find root cause"
history-analyze --ai --limit 200
ai --help    # show runtime info, model, server status
```

Every `ai` call emits an OTel span to the local collector (service: `zdots-shell`).

If the server is down, `ai` fails fast:

```
ai: llama.cpp server not responding at http://127.0.0.1:8080
    Start it with: llama-ctl start
```

### `ai-query` — subprocess-safe script

**The `ai` function is a zsh function. It cannot be called from bash
subprocesses, agent sandboxes, or any context without the interactive zsh
environment loaded.** This includes Claude Code's Bash tool, scripts, CI, and
any non-interactive shell.

`bin/ai-query` is the solution — a plain bash script that calls the same HTTP
API and is accessible from any context:

```sh
# Same interface as `ai`
ai-query "What does SIGPIPE mean?"
git diff | ai-query "Write a commit message"
cat error.log | ai-query "Find the root cause"

# Extra options
ai-query --system "You are a JSON formatter" "pretty print this" < data.json
ai-query --model local --endpoint http://127.0.0.1:8080 "prompt"
ai-query --help
```

**Options:**

| Flag | Short | Description |
|---|---|---|
| `--system TEXT` | `-s` | Override system prompt |
| `--model NAME` | `-m` | Override model name (default: `local`) |
| `--endpoint URL` | `-e` | Override server URL |
| `--help` | `-h` | Show usage |

**Environment variables** (fall through from shell if set, otherwise defaults):

| Variable | Default | Description |
|---|---|---|
| `ZDOTS_AI_ENDPOINT` | `http://127.0.0.1:8080` | Server base URL |
| `ZDOTS_AI_MODEL` | `local` | Model name / alias |

`ai-query` does not emit OTel spans (no shell environment to read trace IDs from).
Use `llama-ctl health` to check server state from a subprocess.

---

## Health Check

```sh
llama-ctl health && echo "up" || echo "down"

# Raw endpoints
curl -sf http://127.0.0.1:8080/health
curl -sf http://127.0.0.1:8080/v1/models | jq '.data[0].id'

# Full server properties
curl -sf http://127.0.0.1:8080/props | jq '{total_slots, model_path}'
```

---

## Update Path

```sh
brew upgrade llama.cpp    # update binary
llama-ctl install         # regenerate plist with new binary path + restart
```

Or via the zdots upgrade alias if wired:

```sh
upgrade-ai   # brew upgrade + re-hydrate model if missing + prune stale GGUFs
```

---

## Configuration Reference

### Adjusting context size

```yaml
# etc/ai-models.yaml — per profile
profiles:
  standard:
    ctx_size: 65536   # double context; uses ~2x KV cache memory
```

### Adjusting generation cap

```yaml
server:
  n_predict: 4096   # raise for long code generation
  n_predict: -1     # remove cap entirely
```

### Adjusting KV cache memory

```yaml
server:
  cache_type_k: f16   # restore default (higher memory, no quality change)
  cache_type_v: f16
  # or go further:
  cache_type_k: q4_0  # experimental, reduces memory further
  cache_type_v: q4_0
```

### Disabling prefix cache reuse

```yaml
server:
  cache_reuse: 0
```

### Changing the API model alias

```yaml
server:
  alias: "gpt-3.5-turbo"   # for integrations that hard-code this name
  alias: ""                  # use the GGUF filename as the model ID
```

### Reducing memory pressure

```yaml
server:
  parallel: 1    # one slot instead of two; halves KV cache footprint
```

---

## Agent Notes

- **Calling AI from a subprocess/agent:** Do NOT use the `ai` zsh function —
  it requires an interactive zsh session. Use instead:
  - `ai-query <prompt>` — the subprocess-safe bash script in `bin/`
  - `curl` directly to `http://127.0.0.1:8080/v1/chat/completions`
  - `llama-ctl <command>` — the lifecycle script works from any bash context
- **Binary not installed:** `llama-ctl install` before any inference.
- **Model not downloaded:** `llama-ctl model-download` before the second `llama-ctl install`.
- **Config changes:** `llama-ctl install` is the only command needed — rewrites the plist and restarts the server.
- **Composition root:** `ZDOTS_SERVICE_AI=llama-cpp` in `.zdots.env`. Changing this switches the entire AI subsystem.
- **Port conflict:** Never run Ollama and the Homebrew `llama-server` on port 8080 simultaneously.
- **OOM:** Reduce `parallel: 1` or switch to `constrained` profile.
- **Default profile:** `default_profile` in yaml is authoritative when `ZDOTS_AI_PROFILE` is not exported.
- **Model name in API calls:** Always use `model: "local"` (the alias). Survives profile switches.
- **Log file:** `~/.local/state/zsh/llama-server.log`
- **Plist:** `~/Library/LaunchAgents/com.zdots.llama-server.plist`
- **Crash throttle:** launchd waits 10s between restarts (`ThrottleInterval: 10`).
