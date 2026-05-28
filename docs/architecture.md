---
id: architecture
title: "Zdots Architecture: Modular Control Plane"
purpose: Core architectural documentation for the Zdots environment.
rationale: Defines the SOLID/DDD principles applied to the shell to ensure long-term maintainability and observability.
links:
  - id: env_posix
    rel: dependency
  - id: providers
    rel: implementation
---

# Zdots Architecture: Modular Control Plane

This document describes the architectural principles, loading sequence, and lifecycle management of the Zdots environment.

## 1. Core Principles

Zdots is designed as an **Observable Control Plane** rather than a static configuration. It applies software engineering best practices to the shell:

- **Domain-Driven Design (DDD)**: Logic is partitioned into "Services" (e.g., Package Management, Node Runtime).
- **Dependency Injection (DI)**: Specific implementations (Providers) are injected at runtime based on the environment.
- **SOLID Principles**: Providers are interchangeable (Liskov Substitution), and core logic depends on abstractions rather than concrete paths (Dependency Inversion).
- **Observability**: Built-in W3C Trace Context propagation and OTLP-compatible telemetry.

---

## 2. Shell Loading Sequence

The following diagram illustrates the boot sequence from the moment a shell process starts.

```mermaid
sequenceDiagram
    participant OS as Operating System
    participant ENV as env.sh (POSIX)
    participant MAN as .zdots.env (Manifest)
    participant PRV as providers/ (DI)
    participant ZSH as .zshrc (Zsh)
    participant CFG as conf.d/ (Interfaces)

    OS->>ENV: Source .zshenv / env.sh
    ENV->>MAN: Load Environment Profile
    MAN-->>ENV: Export ZDOTS_SERVICE_*
    
    rect rgb(200, 230, 255)
    Note over ENV,PRV: Dependency Injection Phase
    ENV->>PRV: zdots_require <service> <provider>
    PRV-->>ENV: Inject _init() and _paths()
    end

    ENV->>ENV: Construct PATH (SOLID precedence)
    
    Note over ZSH: Login/Interactive Entry
    ZSH->>CFG: Source conf.d/*.zsh
    
    rect rgb(220, 255, 220)
    Note over CFG,PRV: Interface Implementation
    CFG->>PRV: Call injected _init()
    PRV-->>CFG: Service Ready
    end
```

---

## 3. Environment Provider Pattern

The system uses a **Composition Root** (`.zdots.env`) to map abstract services to concrete providers.

### Profiles
- **`macos-standard`**: Optimized for local development with Homebrew and Mise.
- **`ci-act`**: Minimalist profile for Linux/GHA, avoiding Mac-specific paths and using system runtimes.

### Service Mapping
| Service | Providers | Responsibility |
| :--- | :--- | :--- |
| `PKG_MANAGER` | `homebrew`, `apt`, `none` | Path setup, `brew shellenv`, package caching. |
| `NODE_RUNTIME` | `mise`, `system` | Toolchain shims, version management. |
| `TRACE` | `otlp`, `local`, `none` | Session ID, Span rotation, Telemetry export. |
| `AI` | `llama-cpp`, `remote` | Local inference, log parsing, data reduction. |
| `WHISPER` | `whisper-cpp`, `none` | Local audio transcription and meeting notes. |

---

## 4. Service Interface Contracts

Each service type must implement a standard set of functions to ensure **Liskov Substitution**:

### AI Service Contract
- **`zdots_ai_init()`**: Initializes model metadata and performs a non-blocking health check on the inference server.
- **`zdots_ai_infer(prompt, system_prompt)`**: The primary execution engine. It takes a prompt and optional system context and returns raw text.

---

## 4. Observability Control Plane

Every shell session is a root span in a distributed trace.

1. **Identity**: `ZDOTS_TRACE_ID` (32 hex) is generated at boot.
2. **Context**: `TRACEPARENT` is exported for all child processes (W3C standard).
3. **Instrumentation**:
    - `preexec`: Rotates `ZDOTS_SPAN_ID` for every command.
    - `curl`: Wrapper automatically injects the `traceparent` header.
4. **Export**: The `otlp` provider sends JSONL logs to a local collector asynchronously.

## 5. Hybrid Observability Routing

Zdots implements a tiered telemetry routing system to ensure high performance on the host and centralized storage in the control plane.

```mermaid
graph TD
    Shell[Shell / Spans] -->|OTLP HTTP :4318| BMC[Bare Metal OTel Collector]
    Apps[Local Apps / Agents] -->|OTLP :4318| BMC
    
    subgraph Host
        BMC
    end
    
    subgraph Colima / Docker
        LGTM[LGTM Stack]
        Loki[Loki - Logs]
        Tempo[Tempo - Traces]
        Grafana[Grafana - UI]
    end
    
    BMC -->|OTLP :4418| LGTM
    LGTM --> Loki
    LGTM --> Tempo
    Grafana --> Loki
    Grafana --> Tempo
```

1. **Bare Metal Collector (BMC)**: Runs directly on the host. It acts as a high-performance buffer and router. It is the primary "Ground Truth" for local traces.
2. **LGTM Stack**: A bundled observability hub (Loki, Grafana, Tempo, Mimir) running in Colima.
3. **Multi-hop Routing**: BMC forwards all collected spans to the LGTM stack via mapped ports (4417/4418), allowing for long-term storage and advanced visualization in Grafana.

---

## 7. PostgreSQL Intelligence Suite (The Brain)

The platform includes a persistent knowledge store to manage methodologies, lessons, and asynchronous work.

### Database Schema (ER Diagram)
The following diagram illustrates the relational structure of the Shell Brain.

```mermaid
erDiagram
    methodologies ||--o{ jobs : "triggers embedding"
    lessons ||--o{ jobs : "triggers embedding"
    jobs ||--o{ jobs : "chains follow-up"
    session_residue ||--o{ lessons : "promotes to"
    
    methodologies {
        uuid id PK
        text slug UK
        text title
        text content
        text_array tags
        jsonb metadata
        vector embedding "3584 dims"
        timestamptz created_at
    }
    
    lessons {
        uuid id PK
        text content
        text context
        text_array tags
        text source_trace_id
        vector embedding "3584 dims"
        timestamptz created_at
    }
    
    jobs {
        uuid id PK
        text type
        jsonb payload
        job_status status
        int priority
        int attempts
        text trace_id
        text error_message
        text fingerprint UK
        timestamptz next_run_at
        timestamptz created_at
    }

    session_residue {
        uuid id PK
        text trace_id UK
        text summary
        text intent
        text result
        int command_count
        jsonb metadata
        timestamptz processed_into_docs_at
        timestamptz created_at
    }

    command_runs {
        bigserial id PK
        text session_id
        bigint ts
        text cwd
        text cmd
        text args
        int exit_code
        int duration_ms
        text profile
        text host
        timestamptz synced_at
    }

    sync_state {
        text key PK
        text value
        timestamptz updated_at
    }
```

### Job Broker Lifecycle (State Diagram)
Asynchronous tasks transition through the following states, managed by PostgreSQL stored procedures.

```mermaid
stateDiagram-v2
    [*] --> Pending : Enqueued
    
    state Pending {
        [*] --> Ready : next_run_at <= now
        Ready --> [*]
    }
    
    Pending --> Running : claim_next_job()
    
    Running --> Completed : complete_job()
    Completed --> [*]
    
    Running --> Failed : fail_job() (attempts < 3)
    Failed --> Pending : Exponential Backoff
    
    Running --> Dead : fail_job() (attempts >= 3)
    Dead --> Triage : zdots-ctx triage
    
    Triage --> Pending : Requeue
    Triage --> [*] : Delete
```

---

## 8. Command Analytics Pipeline

Shell commands flow through a two-stage write path before landing in PostgreSQL.

```mermaid
flowchart LR
    subgraph Shell["Zsh Shell (conf.d/56-cmd-analytics.zsh)"]
        precmd["_zca_precmd\npreexec hook"]
        redact["_zca_redact\nPHI scrub · suppress check"]
        precmd --> redact
    end

    subgraph WriteBuffer["Write Buffer"]
        redis["Redis\nzdots:cmds:<session> TTL 24h\nRPUSH synchronous"]
        sqlite["SQLite\nhistory.sqlite3\nasync fallback"]
        redis -. "unreachable" .-> sqlite
    end

    subgraph Drain["zdots-ctx sync-history"]
        drain["_drain_redis_to_sqlite\nper-key transaction · DEL after drain"]
        sqlite2["SQLite\nconsolidated"]
        sync["zdots-brain sync-history\nSQLite → PostgreSQL"]
        drain --> sqlite2 --> sync
    end

    subgraph PG["PostgreSQL: my"]
        cr["command_runs\n(dedup by session+ts+cmd)"]
        ss["sync_state\ncursor: last synced rowid"]
    end

    redact -->|"suppressed → dropped"| drop(["dropped"])
    redact -->|"clean / redacted"| redis
    Shell --> Drain
    sync --> cr
    sync --> ss
```

**PHI contract:** `_zca_redact` runs `phi_should_suppress` first. Suppress-flagged commands (connection strings) set `_ZCA_CMD=""` and return — no write to Redis, SQLite, or PostgreSQL. Redact patterns apply `phi_scrub` (sed substitution) before the write.

---

## 9. Local AI Routing Architecture

The AI layer sits between the operator and llama.cpp, enforcing PHI boundaries and injecting domain-specific system prompts. See [local-ai.md](local-ai.md) for full documentation.

### Routing Flow

```mermaid
flowchart LR
    prompt([Prompt]) --> ask[zdots-ask\ndomain router]
    ask -->|keyword scan| domain{Domain}
    domain -->|shell/zle/conf.d| sp["zdots-shell.md"]
    domain -->|ruby/sequel/.rb| rp["zdots-ruby.md"]
    domain -->|phi/encrypt/ssn| pp["zdots-phi.md"]
    domain -->|default| dp["zdots-default.md"]
    sp & rp & pp & dp --> gate[zdots_ai_gate\nPHI boundary]
    gate -->|ZDOTS_AI_MODE=local| llama["llama.cpp\n127.0.0.1:11500\nQwen3-8B"]
    gate -->|ZDOTS_AI_MODE=none| exit2([exit 2])
```

### AI Verification Tiers

| Tier | Tool | What it checks | Speed |
|---|---|---|---|
| Structural | `zdots-ctl check` AI router section | Files present, scripts executable, domain detection correct | < 2s |
| Connection | `tests/llama_integration.rb --quick` | llama.cpp responds, chat + embeddings functional | ~10s |
| Capability | `zdots-quiz --quick` | Local model produces correct zdots conventions | ~20s |
| Full baseline | `zdots-quiz` | All 14 domain cases | ~5 min |

---

## 10. CI/CD Lifecycle & Contract Validation

Zdots uses a tiered validation strategy to ensure environmental stability.

### Tier 1: Capability Report (`bin/capabilities`)
The first step in any CI run. It performs **Contract Testing**:
- Verifies that all providers declared in the manifest exist.
- Validates path health and OTel resource attributes.
- Fails fast if the environment does not match its self-description.

### Tier 2: Regression Suite (`bin/check`)
- **Sanity**: Verifies shell options, history modes, and basic tool presence.
- **TDD (Bats-core)**:
    - `tests/env_posix.bats`: Ensures `env.sh` remains POSIX-compliant.
    - `tests/observability.bats`: Validates Span rotation and Traceparent logic.

### Tier 3: Security (`bin/secret-scan`)
- Scans for leaked credentials using high-confidence patterns.
- Includes a CI diagnostic harness for transparent failure reporting.
