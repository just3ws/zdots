---
id: readme
title: "Zdots: The Deepened Shell Platform"
purpose: Primary entry point and system overview for the Zdots environment.
links:
  - id: architecture
    rel: child
  - id: setup
    rel: child
  - id: configuration
    rel: child
---

# Zdots: The Deepened Shell Platform

```bash
# Cold start — new machine to fully operational in one command:
git clone https://github.com/just3ws/zdots.git ~/.config/zsh && ~/.config/zsh/bin/bootstrap
```

> **Work machine?** Create `.zdots.local` with `ZDOTS_CONTEXT=work` before running bootstrap. See [SETUP.md](SETUP.md).

> Local AI · PHI-safe · OTel-instrumented · 14-case model eval · 303-test Bats suite · Single-command restore

---

Zdots is more than a Zsh configuration; it is a **Deepened Shell Platform** engineered for local AI development and systemic observability. While traditional dotfiles focus on visual aesthetics and aliases, Zdots provides a high-leverage **Control Plane** for local inference, distributed tracing, and declarative service management.

---

## 1. Core Architectural Pillars

Zdots is built on a "Deepened" architectural philosophy: a small number of semantic interfaces providing massive leverage.

| Pillar | Description | Implementation |
|---|---|---|
| **Local AI SOTA** | High-performance inference via **llama.cpp** and **whisper.cpp**. | `llama-ctl`, `whisper-ctl` |
| **Shell Brain** | Structured PostgreSQL storage for methodologies and lessons. | `zdots-ctx`, `ctx-mcp` |
| **System Observability** | Every shell command emits an OTel span to a local **LGTM** stack. | `bin/otel-collector`, `env.sh` |
| **Declarative Lifecycle** | Services define specs; a unified engine handles registration. | `lib/lifecycle.bash` |
| **Sentient Workbench** | Task-driven orchestration, trace propagation, and UX awareness. | `ztask`, `gemini-invoke` |
| **Semantic Config** | Centralized Registry resolves derived endpoints from YAML. | `lib/metadata.bash` |
| **Asset Management** | Unified store for downloading and caching AI model assets. | `lib/model-store.bash` |

---

## 2. Why it's "Deep"

Traditional shell configs are **shallow**: a bug in one service's management logic must be fixed everywhere. Zdots is **deep**:

1.  **Opaque Service Seams**: The orchestrator (`zdots-ctl`) interacts with services (AI, OTel, LGTM) only through their CLI grammar. You can swap a background process for a Docker container without changing the orchestrator.
2.  **Locality of Logic**: `launchd` plist generation, HuggingFace model downloads, and endpoint construction are concentrated in core libraries.
3.  **High-Signal Validation**: Includes a 303-test Bats suite and a high-confidence `secret-scan` to ensure platform integrity on every commit.

---

## 3. The May 2026 AI Stack

Zdots includes a production-grade local AI runtime out of the box:

*   **Inference**: llama.cpp (OpenAI-compatible) using Qwen3-8B Q4_K_M and Nomic embed-v2 MoE.
*   **Transcription**: whisper.cpp for high-speed local audio-to-text.
*   **Guardrails**: `ai-query` wraps LLM calls in security and normalization layers.
*   **Recipes**: Built-in workflows like `transcribe` (audio → transcript → AI summary).

---

## 4. Architecture Diagrams

### System Overview
The Zdots platform operates as a "Sidecar Control Plane" on the host, delegating heavy observability storage to an isolated container stack.

```mermaid
architecture-beta
    group host(logos:apple)[Bare Metal macOS]
    group colima(logos:docker)[Colima Stack]

    service zsh(logos:zsh-icon)[Zsh Shell] in host
    service collector(logos:opentelemetry)[OTel Collector] in host
    service brain(logos:postgresql)[Postgres Brain] in host
    service ai(logos:meta)[llama-cpp 8080] in host
    service embed(logos:meta)[llama-cpp 8090] in host
    service cache(logos:redis)[Redis] in host

    service grafana(logos:grafana)[Grafana] in colima
    service tempo(logos:opentelemetry)[Tempo] in colima
    service loki(logos:opentelemetry)[Loki] in colima

    zsh:R -- L:collector
    collector:B -- T:tempo
    collector:B -- T:loki
    zsh:B -- T:brain
    zsh:L -- R:ai
    brain:R -- L:ai
    zsh:T -- B:cache
    brain:L -- R:embed
```

### Telemetry Signal Flow
Data is captured synchronously by the shell and asynchronously exported/persisted by the collector.

```mermaid
sequenceDiagram
    participant Shell as Zsh Shell
    participant Collector as OTel Collector (Host)
    participant LGTM as LGTM Stack (Colima)
    participant Disk as Local Storage

    Note over Shell: Command Executed
    Shell->>Collector: OTLP Trace Span (HTTP:4318)
    
    par Parallel Export
        Collector->>Disk: Write to collector-traces.json
        Collector->>LGTM: Forward to Tempo/Loki (HTTP:4418)
    end

    Note over LGTM: Data Indexed
    LGTM->>LGTM: Correlate Logs + Traces
```

### Unified Service Lifecycle
A shared engine (`lib/lifecycle.bash`) provides a consistent grammar across all service types.

```mermaid
graph LR
    subgraph ControlPlane ["zdots-ctl (Orchestrator)"]
        A[llama-ctl]
        B[otel-collector]
        C[local-ci]
    end

    subgraph LifecycleEngine ["lib/lifecycle.bash"]
        L1[launchd primitives]
        L2[docker-compose primitives]
        L3[Status/Health Formatters]
    end

    A -- "delegates" --> L1
    A -- "delegates" --> L3
    
    B -- "delegates" --> L1
    B -- "delegates" --> L3
    
    C -- "delegates" --> L2
    C -- "delegates" --> L3

    L3 -- "Standard Output" --> UI[Terminal / JSON]
```

---

## 5. Operational Commands

All components are standalone executables in `bin/`. Full tool reference: [docs/tooling.md](docs/tooling.md).

| Command | Purpose |
|---|---|
| `zdots-ctl` | Platform orchestrator: `up/down/reset/install/check/status` |
| `zdots-ctx` | Knowledge layer CLI: `query/capture/hydrate/sync-history/backup/seed` |
| `ztask` | Task orchestrator: `start/done/stop/status <id>` — hydrates env to a task |
| `zdots-ask` | Domain-aware AI router (shell/ruby/phi/default) |
| `zdots-quiz` | Local model capability probe: `--quick` (3 cases) or full (14 cases) |
| `zdots-keychain` | Secrets management: `add/get/list` — stores to macOS Keychain |
| `zdots-status` | Self-refreshing service + env + storage status panel |
| `zmorning` | Daily context brief + optional Pi orientation |
| `zdash` | fzf task picker wired to Pi↔Aider↔ztask cycle |
| `agent-guide` | Live endpoint + capability map for agent sessions |
| `bench` | Shell startup benchmark; guards 80ms performance budget |
| `gemini-invoke` | Observable Gemini bridge (aliased to `gm`) |
| `llama-ctl` | Local LLM lifecycle, profiles, and hardware tuning |
| `whisper-ctl` | Local transcription engine and model management |
| `ai-query` | Guarded LLM inference with PHI scrubbing |
| `otel-collector` | Bare-metal OTel collector and tracing pipeline |
| `local-ci` | Containerized LGTM stack (Grafana/Loki/Tempo) |
| `secret-scan` | High-confidence credential leak detection |
| `zdots-issue` | Agent help desk: file a bug, question, or capability request |

---

## 6. High-Value Superpowers

### Sentient Workbench
The shell is your prompt interface, providing deep context and task-driven orchestration.

*   **Collaborative Hand-off**: Every agent session (via `gm`) is linked to the shell trace.
*   **Task Hydration**: `ztask start <id>` morphs the environment to match your intent.

### Autonomous Shell Brain (`zdots-ctx`)
Your shell learns as you work, distilling complex sessions into structured knowledge.

```bash
zdots-ctx capture
```

*   **Semantic Memory**: Uses local AI to distill "Intent vs Result" from your OTel traces and history.
*   **Methodology Store**: A permanent PostgreSQL brain for your architectural standards.
*   **AI Bridge (MCP)**: Exposes your brain to AI agents via the Model Context Protocol (`ctx-mcp`) — agents can query standards and contribute new lessons.
*   **Full-Text Search**: Sub-second lookups over your entire history of technical lessons.

### Side-Effect Broker (Job Queue)
Manage high-cost operations (like batch media transcription) securely via PostgreSQL.

```bash
zdots-ctx enqueue transcription '{"url": "https://youtu.be/..."}'
zdots-ctx worker --type transcription
```

*   **Idempotency**: Prevents duplicate jobs by hashing payload and type.
*   **WIP Limits & Concurrency**: Workers process jobs sequentially to protect machine resources (e.g., VRAM, CPU).
*   **Resilience & Backoff**: Exponential backoff for temporary failures and a Dead-Letter Queue (DLQ) for permanent failures.
*   **Observability**: Real-time queue depth exported to the local OpenTelemetry stack (`zdots-ctx metrics-loop`).

### YouTube Transcription (`ztranscribe`)
A high-performance pipeline for deep context extraction from YouTube videos.

```bash
ztranscribe 'https://www.youtube.com/watch?v=...' --diarize
```

*   **Max Quality**: Extracts best audio (`yt-dlp`) → 16kHz Mono (`ffmpeg`) → `large-v3` (`whisper.cpp`).
*   **Multi-Context**: Generates `.txt`, `.json`, `.srt`, `.vtt`, and `.csv` transcripts simultaneously.
*   **Diarization**: Optional `--diarize` flag identifies "who said what" via `pyannote.audio`.
*   **Hygiene**: Automatically discards heavy media files after processing (override with `--keep-media`).
*   **Metadata**: Captures full video metadata in `.info.json` for RAG and archival.

---

## 7. Local AI Routing Layer

Zdots routes every prompt through a domain-aware local LLM layer before any frontier model is considered. The 7B model runs entirely on-device — no cloud egress, no API keys required for covered tasks.

```mermaid
flowchart LR
    subgraph Router["AI Router Layer"]
        direction TB
        ask["<b>zdots-ask</b>\ndomain router"]
        prompts["<b>etc/prompts/</b>\nzdots-{default,shell,ruby,phi}.md"]
        aiquery["<b>ai-query</b>\nguardrail wrapper"]
        boundary["<b>ai_boundary.bash</b>\nPHI gate · endpoint lock"]
        ask -->|selects| prompts
        ask -->|calls| aiquery
        aiquery -->|enforces| boundary
    end

    subgraph Inference["Local Inference (loopback only)"]
        llama["<b>llama.cpp :8080</b><br/>Qwen3-8B Q4_K_M<br/>32k ctx · Metal GPU"]
    end

    subgraph Ops["Verification"]
        ctl["zdots-ctl check"]
        quiz["zdots-quiz\n14-case probe"]
        quiz -->|calls| ask
        ctl -->|inspects| ask
    end

    boundary -->|127.0.0.1:8080 only| llama
```

**Domain routing** — prompt keywords determine which system prompt is injected:

| Domain | Trigger keywords | Covers |
|---|---|---|
| `shell` | zsh · zle · widget · conf.d · zdots-ctl | ZLE widgets, check helpers, AI call pattern, OTel spans |
| `ruby` | sequel · migration · .rb · zdots_rw | Sequel migrations, pgcrypto accessors, PHI columns |
| `phi` | phi · hipaa · ssn · mrn · pgcrypto · encrypt | 6-layer PHI defense, posture verification |
| `default` | *(fallback)* | DB roles, tool names, capture constraints |

All prompts use the **Caveman Voice**: technical precision, zero filler, code first.

```bash
zdots-ask "write ZLE widget that saves BUFFER and opens fzf"   # auto-detects shell
zdots-ask --domain ruby "add nullable column to lessons table"  # explicit domain
zdots-ask --dry-run "is this PHI-safe?"                        # inspect routing
zdots-quiz --quick                                              # 3-case smoke test
```

→ Full documentation: [docs/local-ai.md](docs/local-ai.md)

---

## 8. Setup & Documentation

Refer to [SETUP.md](SETUP.md) for the full clone-to-running walkthrough.

```sh
make bootstrap          # Full platform installation & model hydration
zdots-ctl status        # Confirm entire stack is green
```

*   [docs/architecture.md](docs/architecture.md) — The DI pattern and loading sequence.
*   [docs/local-ai.md](docs/local-ai.md) — Local AI routing layer: architecture, prompts, capability map, quiz.
*   [docs/tooling.md](docs/tooling.md) — Key tools reference: what to reach for and why (organized by workflow).
*   [SETUP.md](SETUP.md) — Clone-to-running on a fresh machine, PHI checklist, work machine setup.
*   [docs/testing.md](docs/testing.md) — How we ensure the build is always green.
*   [AGENTS.md](AGENTS.md) — Orientation for AI agents (Claude, Gemini) including RTK rules.
