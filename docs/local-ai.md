---
id: local-ai
title: "Local AI Routing Layer"
purpose: Architecture, capability map, routing rules, and operational guide for the zdots local LLM system.
links:
  - id: architecture
    rel: parent
  - id: configuration
    rel: sibling
---

# Local AI Routing Layer

Zdots runs a domain-aware routing layer on top of `ai-query` and llama.cpp. Every prompt is classified by domain, enriched with a compact zdots-specific system prompt, and sent to the local Qwen3-8B model. No cloud egress. No frontier model usage for covered tasks.

> **Mission**: Maximum trusted usefulness from local hardware. Frontier models are the exception, not the default.

---

## 1. System Architecture

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
        llama["<b>llama.cpp :8080</b>\nQwen3-8B Q4_K_M + 0.6B draft\n32k ctx · Metal GPU · spec-decoding"]
    end

    subgraph Tools["Operator Tools"]
        zaider["zaider (Aider)"]
        cl["cl (Claude Code)"]
        zpi["zpi (Pi)"]
    end

    subgraph Knowledge["Knowledge Base"]
        ctxcli["zdots-ctx"]
        pg["PostgreSQL: my\nzdots_ro / zdots_rw"]
        ctxcli --> pg
    end

    subgraph Ops["Verification"]
        ctl["zdots-ctl check\nAI router section"]
        quiz["zdots-quiz\n14-case probe"]
        quiz -->|calls| ask
        ctl -->|inspects| ask
    end

    boundary -->|127.0.0.1:8080 only| llama
    zaider -->|local model| llama
    cl -->|frontier · unaffected by ZDOTS_AI_MODE| ext["Anthropic API"]
```

---

## 2. Routing Decision Tree

Every `zdots-ask` call follows this path before the model is touched.

```mermaid
flowchart TD
    A([User prompt]) --> B{--dry-run?}
    B -->|yes| C[Print domain + system prompt\nno model call · exit 0]
    B -->|no| D{--domain\nflag set?}

    D -->|yes| E[Use specified domain]
    D -->|no| F{Keyword scan\nof prompt text}

    F -->|phi · hipaa · ssn · mrn\npgcrypto · encrypt · audit| G[phi]
    F -->|ruby · sequel · migration\n.rb · zdots_rw · zdots_ro| H[ruby]
    F -->|zsh · bash · zle · widget\nconf.d · zdots-ctl · ztask| I[shell]
    F -->|no match| J[default]

    G --> K[etc/prompts/zdots-phi.md]
    H --> L[etc/prompts/zdots-ruby.md]
    I --> M[etc/prompts/zdots-shell.md]
    J --> N[etc/prompts/zdots-default.md]

    K & L & M & N --> O[zdots_ai_gate]

    O -->|ZDOTS_AI_MODE=none| P([exit 2\nhuman-readable message])
    O -->|ZDOTS_AI_MODE=local| Q[zdots_assert_local_endpoint]

    Q -->|non-RFC-1918| R([exit 1\nendpoint blocked])
    Q -->|127.x / 10.x / 192.168.x| S["ai-query --mode raw\n--system &lt;prompt&gt;\nAIQ_SUPPRESS_RAW_WARN=1"]

    S --> T{Response\nempty?}
    T -->|yes| U[sleep 2s · retry]
    U --> V{Empty\nagain?}
    V -->|yes| W([WARN stderr\nreturn empty])
    V -->|no| X([Return response])
    T -->|no| X
```

---

## 3. Failure Behavior

Zdots has no frontier fallback. `ZDOTS_AI_MODE=local` is enforced at the boundary layer until security setup is complete. Every failure exits cleanly — no hangs, no curl timeouts exposed to callers.

```mermaid
stateDiagram-v2
    [*] --> Received: prompt arrives

    Received --> AIGate
    AIGate --> Blocked: ZDOTS_AI_MODE=none\nexit 2 · clean message
    AIGate --> EndpointCheck: ZDOTS_AI_MODE=local

    EndpointCheck --> PHIBlock: non-RFC-1918 endpoint\nexit 1
    EndpointCheck --> Inference: loopback confirmed

    Inference --> EmptyCheck: response received
    Inference --> Retry: empty response

    Retry --> EmptyCheck: non-empty on retry
    Retry --> WarnEmpty: empty again\nWARN stderr

    EmptyCheck --> Returned: content present
    WarnEmpty --> Returned: empty returned\ncaller handles

    Returned --> [*]
    Blocked --> [*]
    PHIBlock --> [*]

    note right of Blocked
        zdots_ai_gate — used by
        every AI-touching script.
        ZDOTS_AI_MODE=none is a
        safe baseline, not degraded.
    end note

    note right of PHIBlock
        zdots_assert_local_endpoint.
        Non-RFC-1918 = hard fail.
        No data leaves machine.
    end note

    note right of WarnEmpty
        No frontier fallback.
        By design. ZDOTS_AI_MODE=local
        until security complete.
    end note
```

---

## 4. System Prompt Architecture

Four domain prompts in `etc/prompts/`. Each is compact. llama.cpp's built-in prompt cache (enabled by default, 8192 MiB budget) caches the KV prefix after the first call per session; subsequent calls pay near-zero prefill cost. (`--cache-reuse` is not used — it conflicts with speculative decoding.)

All prompts open with the **Caveman Voice** instruction: technical precision, zero filler, code first.

```mermaid
xychart-beta
    title "Prompt sizes vs. 256-token cache_reuse threshold"
    x-axis ["zdots-default", "zdots-phi", "zdots-ruby", "zdots-shell"]
    y-axis "Estimated tokens" 0 --> 500
    bar [255, 300, 310, 410]
    line [256, 256, 256, 256]
```

| Prompt | Domain trigger keywords | Load-bearing patterns |
|---|---|---|
| `zdots-default.md` | *(fallback)* | DB roles, tool names, capture constraints, OTel context |
| `zdots-shell.md` | zsh · bash · zle · widget · conf.d · zdots-ctl | ZLE widgets, check helpers, AI call, Keychain, `stat -f`, OTel spans |
| `zdots-ruby.md` | ruby · sequel · migration · .rb · zdots_rw | Migration skeleton, pgcrypto accessors, PHI column list, `rescue Sequel::DatabaseError` |
| `zdots-phi.md` | phi · hipaa · ssn · mrn · pgcrypto · encrypt | 6-layer defense table, PHI script preamble, posture verification |

---

## 5. Capability Delegation Map

```mermaid
quadrantChart
    title What task goes where
    x-axis Deterministic ──────────────────── Requires Judgment
    y-axis Low Stakes ──────────────────────── High Stakes

    quadrant-1 Frontier model only
    quadrant-2 Human review required
    quadrant-3 Unix tools (grep/jq/git/psql)
    quadrant-4 zdots-ask — local LLM

    ZLE widget skeleton: [0.55, 0.22]
    Sequel migration skeleton: [0.58, 0.28]
    PHI boundary pattern: [0.48, 0.18]
    DB role selection: [0.28, 0.12]
    Posture check command: [0.22, 0.08]
    OTel span emission: [0.52, 0.20]
    zdots-ctx capture: [0.48, 0.32]
    Git log search: [0.08, 0.05]
    grep rg fd: [0.05, 0.04]
    jq awk transform: [0.10, 0.08]
    SQL exploration: [0.12, 0.10]
    Multi-file refactor: [0.88, 0.68]
    Architecture decision: [0.92, 0.58]
    Novel problem solving: [0.95, 0.52]
    PHI data handling: [0.72, 0.92]
    Direct code mutation: [0.62, 0.88]
```

**Never route locally:**
- Multi-file architectural decisions
- Novel problems with no prompt coverage (model will hallucinate)
- Anything requiring post-2025 external knowledge
- Direct code mutation without human review (`zaider` handles mutation with git safety)

**Never replace with LLM:**
- `rg` / `fd` / `find` — file search
- `jq` / `awk` — structured data extraction  
- `git log` / `git blame` — history
- `psql -U zdots_ro my` — database exploration

---

## 6. New Machine Verification Sequence

```mermaid
flowchart TD
    A([Fresh macOS\nApple Silicon]) --> B[bin/bootstrap\nBrewfile · XDG · Ruby · links]
    B --> C[Edit .zdots.local\nZDOTS_CONTEXT=home or work]

    C --> D{work machine?}
    D -->|yes| E[Provision\nZDOTS_DB_ENCRYPTION_KEY\nin Keychain]
    E --> F[zdots-ctx migrate\nencrypts PHI columns]
    F --> G
    D -->|no| G[llama-ctl install\n~5.4 GB · main + draft model]

    G --> H[zdots-ctl up]
    H --> I["zdots-ctl check\nFileVault · SIP · Firewall\nAI router · model hash · audit log"]
    I --> J{All pass?}
    J -->|no| K[Fix flagged items\nre-run check]
    K --> J
    J -->|yes| L["zdots-quiz --quick\nTC-03 · TC-07 · TC-09 · ~20s"]
    L --> M{3/3 pass?}
    M -->|no| N[zdots-quiz --verbose\ntune etc/prompts/]
    N --> L
    M -->|yes| O([Fully operational ✓\nzdots-ask ready])
```

`llama-ctl install` downloads ~5.4 GB (Qwen3-8B Q4_K_M ~5.0 GB + Qwen3-0.6B draft ~0.4 GB). Start it before other setup steps. Use `llama-ctl model-download --draft` to download only the draft model.

---

## 7. Gap Map — Priority vs. Effort

```mermaid
quadrantChart
    title Backlog: priority vs. effort
    x-axis Low Effort ──────────────────────── High Effort
    y-axis Low Priority ─────────────────────── High Priority

    quadrant-1 Do now
    quadrant-2 Plan carefully
    quadrant-3 Skip or defer indefinitely
    quadrant-4 Backlog

    zdash fzf quiz TC-15: [0.22, 0.38]
    llama-ctl quiz TC-16: [0.22, 0.32]
    Output contracts DRAFT-001: [0.62, 0.28]
    Context hydration Z-092: [0.55, 0.68]
    Routing confidence: [0.65, 0.25]
    Frontier escalation path: [0.72, 0.48]
    Full OTel instrumentation: [0.78, 0.20]
```

| Task | Priority | Trigger to start |
|---|---|---|
| Z-092 Context hydration | Medium | Stateless answers prove insufficient for "what next?" tasks |
| Z-093 zdash/llama-ctl quiz | Low | Those task types come up in real usage |
| DRAFT-001 Output contracts | Low | Hallucination rate on real tasks exceeds acceptable threshold |

---

## 8. Usage

```bash
# Auto-detect domain from keywords
zdots-ask "explain how ZLE widget saves BUFFER"

# Force domain
zdots-ask --domain ruby "write migration for new column on lessons"

# Inspect routing without inference
zdots-ask --dry-run "is this pattern PHI-safe?"

# Probe model capability
zdots-quiz --quick          # 3 cases, ~20s — run on new machine
zdots-quiz                  # full 14-case baseline
zdots-quiz --verbose        # show model responses for failed cases
zdots-quiz TC-07 --verbose  # single case debug

# Domain list
zdots-ask --list-domains
```
