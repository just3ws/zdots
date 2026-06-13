# Zdots Glossary — Formal Definitions

A comprehensive reference of zdots terminology. Terms are ordered by domain and linked to related concepts.

---

## Platform Services

### Service / Platform Service

**Definition:** A long-running process managed by zdots with declarative lifecycle (start, stop, restart) and health probing.

**Etymology:** From launchctl, kubectl patterns.

**Antonym:** Ephemeral process (cli tool, one-shot script).

**Attributes:**
- Startable, stoppable, restartable
- Health-probeable (liveness check)
- Tracked in `bin/svc-registry.bash`
- Discoverable via `zdots_svc_resolve()`

**Examples:**
- llama (AI inference)
- whisper (transcription)
- otel-collector (observability)
- context-engine (knowledge persistence)

**Related:** Core Service, Cache Service, Hosted Service, Health.

**Usage:** "Start the llama service: `zsvc start llama`"

---

### Core Service

**Definition:** A Platform Service that zdots itself depends on to function. Always present.

**Contrast:** Cache Service (graceful degradation), Hosted Service (optional).

**Examples:** llama, whisper, otel-collector, context-engine, Worker.

**Usage:** "The Worker is a Core Service; if it's down, jobs won't drain."

---

### Cache Service

**Definition:** A Platform Service that improves throughput but the system degrades gracefully if absent.

**Contrast:** Core Service (required), Hosted Service (unrelated to zdots).

**Examples:** Redis (command analytics buffer; fallback to SQLite).

**Usage:** "Redis is a Cache Service; if it's unreachable, commands are written to SQLite instead."

---

### Hosted Service

**Definition:** A Platform Service that zdots manages on behalf of a project or workload, but zdots doesn't depend on it.

**Contrast:** Core Service, Cache Service.

**Examples:** wwworkremote (job search), Phalanx Duel (game management).

**Usage:** "Deploy Phalanx Duel as a Hosted Service via `zsvc start phalanx`."

---

### Health

**Definition:** The liveness state of a Platform Service. Probed by `zdots_svc_healthy()` and reported in `zsvc status`.

**Related:** Service Registry, Platform Service.

**Values:** Healthy (probed successfully), Unhealthy (probe failed or timeout).

**Usage:** "Check llama health: `zsvc health llama`"

---

## Knowledge Layer

### Knowledge Base

**Definition:** The personal "second brain" stored in PostgreSQL (`my` database). Contains curated lessons, methodologies, and session residue.

**Related:** Knowledge Layer, Lesson, Methodology, Session Residue, Virtuous Loop.

**Gateway:** `zdots-brain` (sole read/write interface).

**Usage:** "Query the Knowledge Base: `zdots-ctx query lessons:*`"

---

### Knowledge Layer

**Definition:** The stack of abstractions above Platform Services that enables AI-assisted learning: Knowledge Base + Virtuous Loop + AI Invocation.

**Etymology:** Previously called "Intelligence Suite"; renamed for clarity.

**Related:** Knowledge Base, Worker, Virtuous Loop.

**Scope:** Local-only (never reaches cloud).

**Usage:** "The Knowledge Layer is how zdots improves over time."

---

### Lesson

**Definition:** A curated knowledge unit: atomic, tagged, with content and context. Promoted from Session Residue or authored directly.

**Related:** Session Residue, Methodology, Knowledge Base.

**Attributes:**
- Content (text)
- Context (optional background)
- Tags (searchable)
- Created/updated timestamps
- Source (Session Residue trace_id, or authored)

**Usage:** "Promote this session residue to a Lesson: `zdots-ctx promote <residue_id>`"

---

### Methodology

**Definition:** A synthesized, higher-level knowledge artifact: stable principles derived from multiple lessons.

**Contrast:** Lesson (atomic unit), Session Residue (raw capture).

**Attributes:**
- Slug (stable upsert key)
- Title
- Content
- Tags

**Usage:** "Document the CI/CD onboarding as a Methodology."

---

### Session Residue

**Definition:** Raw distillation of a captured shell session: intent, result, summary, linked by trace_id.

**Related:** Virtuous Loop, Lesson, Capture.

**Lifecycle:**
- `captured` — from `zdots-ctx capture`
- `unprocessed` → `processed` — curation via `processed_into_docs_at` flag

**Usage:** "Review unprocessed session residue: `zdots-ctx query residue: processed_into_docs_at:null`"

---

### Capture

**Definition:** The act of distilling a shell session into Session Residue. Triggered by `zdots-ctx capture`.

**Related:** Virtuous Loop, Distill, Session Residue.

**Process:**
1. Collect command history + traces from session
2. Normalize and scrub (PHI, credentials)
3. Invoke AI to distill into intent/result/summary
4. Store as Session Residue in Knowledge Base
5. Enqueue Jobs (embed, docs_sync)

**Usage:** "Capture this session: `zdots-ctx capture`"

---

### Curate

**Definition:** The act of reviewing and refining captured sessions into polished lessons and methodologies.

**Related:** Session Residue, Lesson, Methodology, Virtuous Loop.

**Tools:** Pi (interactive curation), manual edits in Obsidian Knowledge Vault.

**Usage:** "Curate session residue into lessons to improve future AI context."

---

### Virtuous Loop

**Definition:** The positive feedback cycle: Work → Capture → Curate → Infer → Repeat.

**Related:** Knowledge Base, Knowledge Layer, Capture, Lesson.

**Trust property:** Because all agent actions are captured and fed back as lessons, unexpected behavior becomes learning rather than invisible failure.

**Usage:** "The Virtuous Loop is zdots' governance mechanism."

---

### Knowledge Vault

**Definition:** The Obsidian-managed document directory (~/my/knowledge/) that is the source of truth for the Knowledge Base.

**Related:** Knowledge Base, Lesson, Methodology.

**Structure:**
- `inbox/` — fast capture, unprocessed
- `lessons/` — atomic units (maps to `lessons` table)
- `methodologies/` — synthesized principles (maps to `methodologies` table)
- `references/` — external sources

**Usage:** "Edit lessons in Obsidian Knowledge Vault; ingest to PostgreSQL via `zdots-ctx sync-docs`."

---

## Data & Messaging

### Message Hygiene Pipeline

**Definition:** The ordered sequence of transformations applied to text before inference or persistence.

**Stages (order matters):**
1. Normalize — strip artifacts (null bytes, ANSI, CRLF, C0 control chars)
2. PHI Scrub — remove sensitive patterns

**Interface:** `zdots_message_hygiene()` in `lib/message_hygiene.bash`.

**Failure modes:** Non-zero exit if PHI unavailable or suppress-match detected.

**Usage:** "All text entering inference must pass Message Hygiene: `echo "$text" | zdots_message_hygiene`"

---

### PHI / PHI Protection

**Definition:** Protected Health Information — sensitive data requiring redaction or suppression before persistence or inference.

**Scope:** SSN, MRN, DOB, database connection strings, credential patterns.

**Mechanisms:**
- Redaction — replace with placeholder (e.g., `[REDACTED-SSN]`)
- Suppression — fail hard if match (for connection strings; no partial output)

**Related:** PHI Pattern Registry, PHI Scrubber, Message Hygiene Pipeline.

**Usage:** "The context-engine pipeline scrubs all input via `Zdots::AI::PhiScrubber.call(text)`."

---

### PHI Pattern Registry

**Definition:** The canonical list of sensitive-pattern rules. Single source of truth.

**Location:** `etc/phi-patterns.yaml`

**Format:** YAML array of patterns; each has name, regex, replacement, optional suppress flag.

**Invariant:** New PHI patterns require exactly one file edit (`etc/phi-patterns.yaml`). No other file may define patterns.

**Consumers:**
- `lib/phi_scrubber.bash` — compiles to sed args
- `lib/zdots/ai/phi_scrubber.rb` — Ruby twin
- `cmd/zdots-phi-scrub/` — Go canonical impl

**Usage:** "Add a new sensitive pattern: edit `etc/phi-patterns.yaml` once."

---

### PHI Scrubber

**Definition:** The component that enforces PHI protection via redaction and suppression.

**Implementation:** Canonical Go binary (`cmd/zdots-phi-scrub/main.go`); called by bash and Ruby adapters.

**Interface:**
- `zdots-phi-scrub` (stdin → redacted stdout; hard fail on suppress)
- `zdots-phi-scrub --check` (predicate: 0 if suppress-match, 1 if not)

**Related:** PHI Pattern Registry, Message Hygiene Pipeline.

**Usage:** "Scrub a prompt: `echo "$prompt" | zdots-phi-scrub`"

---

### Command Analytics

**Definition:** Real-time capture of every shell command with exit code, duration, CWD, and session context.

**Write path:** Precmd hook → Redis (sync, primary) → SQLite (async, fallback).

**Drain path:** `zdots-ctx sync-history` → Redis → SQLite → PostgreSQL.

**PHI contract:** All commands pass through `_zca_redact()` before write. Suppress-flagged commands dropped entirely.

**Enable:** `ZDOTS_CMD_ANALYTICS=1` (off by default; disabled on work machines).

**Related:** Virtuous Loop, Analytics Buffer.

**Usage:** "Enable analytics: `export ZDOTS_CMD_ANALYTICS=1` in `.zdots.local`"

---

### Analytics Buffer

**Definition:** The dual-write system for command history (Redis + SQLite) with orchestrated drain.

**Current issue:** Write paths not equivalent; caller orchestrates fallover.

**Speculative improvement (ADR pending):** Unify behind a single buffer interface.

**Related:** Command Analytics, Cache Service.

**Usage:** "Sync history to PostgreSQL: `zdots-ctx sync-history`"

---

## AI & Inference

### AI Invocation Interface

**Definition:** The seam through which all local AI inference is called. Lives in `lib/ai-invoke.bash`.

**Functions:**
- `zdots_ai_infer_raw()` — stdin → stdout (raw text)
- `zdots_ai_distill()` — stdin → stdout (JSON)

**Contract:** Caller owns prompt; function owns gate, hygiene, submission, parsing.

**Gate checks:**
- ZDOTS_AI_MODE (must be `local`)
- Endpoint locality (loopback or RFC-1918)

**Hygiene:** Runs `zdots_message_hygiene()` on input (normalize → PHI scrub).

**Related:** AI Boundary, Message Hygiene Pipeline.

**Usage:** "Infer via the seam: `echo "$prompt" | zdots_ai_infer_raw`"

---

### AI Boundary

**Definition:** The gatekeeping layer that prevents inference calls when not in local mode or endpoint is non-local.

**Checks:**
- Mode check — exits 2 if `ZDOTS_AI_MODE=none`
- Locality check — exits 1 if endpoint is non-local in local mode

**Location:** `lib/ai_boundary.bash` (predicate/adapter split).

**Related:** AI Invocation Interface, ADR-0001 (nginx not in CLI path).

**Usage:** "Check boundary: `zdots_ai_gate` before calling inference."

---

### Domain Router

**Definition:** The AI request router that selects a model or prompt style based on domain tags.

**Related:** `zdots-ask --domain ruby`.

**Example:** "Ask about Ruby best practices: `zdots-ask --domain ruby "how do I..."`"

---

### Trace / Trace ID

**Definition:** A unique identifier for a request's execution path. Links commands, spans, and logs.

**Related:** Observability, OTEL, Session Residue.

**Propagation:** Via environment variable (zsh provider), or manually in bash fallback.

**Usage:** "Query a trace: `zdots-o2-query trace <id>`"

---

### Distill / Distillation

**Definition:** AI-powered summarization of raw data (session history, transcripts) into structured form (intent, result, summary).

**Related:** Session Residue, Capture, Job (distill type).

**Process:** Raw text → AI → JSON (intent, result, summary) → Session Residue.

**Usage:** "Distill a session: `zdots-ctx capture` enqueues a distill job."

---

## Observability

### OTEL / OpenTelemetry

**Definition:** Standard protocol for tracing and metrics. Used by zdots for observability.

**Collector:** `otel-collector` service (Docker or native).

**Span:** A named unit of work with start/end time, status, attributes, events.

**Metric:** A measurement (counter, gauge, histogram).

**Related:** Trace, Observability.

**Usage:** "View traces in OpenObserve: `zdots-o2-query trace <id>`"

---

### Observability

**Definition:** The ability to query and understand system behavior via traces, metrics, and logs.

**Stack:**
- **Tracer** — emits spans (zsh provider via OTEL, bash fallback)
- **Collector** — aggregates traces/metrics (otel-collector, OpenObserve)
- **Query** — search and analyze (zdots-o2-query, Grafana dashboards)

**Related:** OTEL, Trace, Span.

**Usage:** "Check observability status: `zdots-ctl check`"

---

## Control & Orchestration

### Seam

**Definition:** A place where behavior can be altered without editing in place. An interface point.

**Examples:**
- Service Registry — metadata; health-check dispatch via registry entry
- Message Hygiene — interface hiding normalize + PHI scrub
- AI Invocation — gate, hygiene, submission all behind one call

**Related:** Adapter, Interface, Depth.

**Usage:** "The Service Registry is a seam for adding new services."

---

### Adapter

**Definition:** A concrete implementation of an interface at a seam.

**Examples:**
- `lib/phi_scrubber.bash` — bash adapter calling Go binary
- `lib/zdots/ai/phi_scrubber.rb` — Ruby adapter calling Go binary
- Individual `*-ctl` scripts — service adapters to registry metadata

**Related:** Seam, Interface.

**Usage:** "The bash adapter is a thin wrapper around the Go binary."

---

### Interface

**Definition:** Everything a caller must know to use a module: types, invariants, error modes, ordering, config.

**Contrast:** Implementation (the code inside).

**Related:** Seam, Adapter, Depth.

**Usage:** "The interface of `phi_scrub` is: stdin → stdout, hard fail on suppress."

---

### Depth

**Definition:** Leverage at the interface: a lot of behavior behind a small interface.

**Antonym:** Shallow (interface nearly as complex as implementation).

**Benefits:** Testability, locality (changes concentrated), leverage (callers thinner).

**Related:** Interface, Seam.

**Usage:** "The Message Hygiene Pipeline has depth: two stages, one interface."

---

### Locality

**Definition:** Concentration of knowledge and change in one place.

**Benefit of depth:** Bug fixes, understanding, maintenance concentrated at the seam.

**Antonym:** Scattered logic (same behavior across many callers).

**Usage:** "The Service Registry improves locality: health-check logic lives once."

---

## Configuration & State

### Configuration / Config

**Definition:** All settings, environment variables, service descriptors, and schema versions.

**Current state:** Scattered (`.zdots.local`, `.claude/settings.json`, `etc/phi-patterns.yaml`, migrations, plists).

**Ideal state (speculative):** Unified DSL with schema validation, versioning, templating.

**Related:** Workflow, Template, Environment.

**Usage:** "Get a config value: `zdots config get AI_MODE`"

---

### Workflow

**Definition:** A declarative, composable sequence of commands with dependencies and error handling.

**Location:** `.zdots/workflows/*.yaml`

**Interface:** `zdots workflow <verb> <name>` (run, list, status, validate).

**Related:** Configuration, Job, Automation.

**Usage:** "Run a workflow: `zdots workflow run daily-sync`"

---

### Template / Templating

**Definition:** A reusable blueprint for service config, workflow, or full environment state.

**Use cases:** Reproducibility, onboarding, disaster recovery.

**Speculative interface:**
```
zdots template list
zdots template apply template.yaml
zdots template export > backup.yaml
```

**Related:** Configuration, Environment, Workflow.

---

### Environment

**Definition:** An isolated, copyable zdots state (config, services, schema).

**Use case:** Testing, multi-workstation setup, CI/CD parity.

**Speculative interface:** `zdots env new`, `zdots env activate`, `zdots env copy`, `zdots env delete`.

**Related:** Configuration, Template.

**Usage:** "Test in an isolated environment: `ZDOTS_ENV=test zdots-ctl up`"

---

### Job

**Definition:** A unit of async work in the Knowledge Layer job queue.

**Types:** `embed`, `distill`, `docs_sync`, `transcription`.

**Lifecycle:** `pending` → `running` → `complete` | `failed`.

**Processor:** The Worker (Core Service).

**Speculative interface:** `zdots job enqueue`, `zdots job list`, `zdots job watch`.

**Related:** Worker, Knowledge Layer, Workflow.

**Usage:** "List pending jobs: `zdots job list --status pending`"

---

## Access & Safety

### Actor

**Definition:** A named principal (human, agent, service) with role and permissions.

**Use case:** Multi-agent safety, compliance, audit trail.

**Speculative attributes:** Name, role, permission allow/deny list.

**Related:** Access Control, Audit.

**Usage:** "Add an agent: `zdots actor add pi-agent --role researcher`"

---

### Access Control

**Definition:** Roles, permissions, and delegation policy for multi-agent environments.

**Speculative model:** Actor + roles + allow/deny rules per command.

**Related:** Actor, Audit, Actor.

**Usage:** "Check if agent can query: `zdots actor check permission pi-agent 'zdots-ctx query'`"

---

### Audit

**Definition:** Log of who did what, when, and why. For compliance and debugging.

**Speculative interface:** `zdots audit --actor <name> --last 1h`.

**Related:** Access Control, Actor.

**Usage:** "Review Pi's actions: `zdots audit --actor pi-agent --last 1h`"

---

### Alert

**Definition:** A condition-based notification and remediation rule.

**Attributes:** Name, condition, threshold, severity, actions (notify/remediate/escalate).

**Speculative interface:** `zdots alert list`, `zdots alert silence`, `zdots alert status`.

**Related:** Health, Observability.

**Usage:** "Silence an alert: `zdots alert silence llama_down --for 1h`"

---

## Capability & Discovery

### Capability

**Definition:** An advertised operation or facility that zdots provides.

**Types:** Operation (verb), check (predicate), resource.

**Attributes:** Name, type, requires (dependencies), attestation (proof of availability).

**Speculative interface:** `zdots capability list`, `zdots capability check`, `zdots capability query`.

**Related:** Observability, Health.

**Usage:** "Does this machine have AI? `zdots capability check does-ai-inference`"

---

### Discovery / Introspection

**Definition:** Programmatic querying of what zdots can do, what services are available, what commands exist.

**Contrast:** Manual inspection via `--help`, docs.

**Speculative interface:** `zdots capability list`, `zdots command list`, `zdots agent list`.

**Usage:** "List all commands: `zdots command list --domain knowledge`"

---

## Process & Scripting

### Script / Scripting

**Definition:** A multi-command sequence with variables, conditionals, and error handling.

**Current state:** Shell scripts (bash, zsh); hard to port, test, audit.

**Speculative DSL:** Zdots scripting language (typed, portable, testable).

**Speculative interface:** `zdots script run`, `zdots script test`, `zdots script schedule`.

**Related:** Workflow, Automation.

**Usage:** "Run a script: `zdots script run health-check`"

---

### Automation

**Definition:** The composition and execution of multi-command workflows or scripts.

**Mechanisms:** Workflows, scripts, cron, webhooks, manual triggers.

**Related:** Workflow, Script, Trigger.

**Usage:** "Automate daily sync: define a workflow with cron trigger."

---

### Trigger

**Definition:** An event that starts a workflow or script.

**Types:** `cron` (time-based), `webhook` (HTTP), `manual` (user request), `event` (state change).

**Related:** Workflow, Automation.

**Usage:** "Define a trigger: `trigger: cron "0 9 * * *"`"

---

## Style & Communication

### Kevin's Law

**Definition:** "Why waste time, say lot word when few word do trick?" — Kevin Malone. Applied to code, docs, and communication.

**Principle:** No filler, no hedging, no pleasantries. Code first. Technical terms exact.

**Scope:** Comments, commit messages, issue descriptions, PR bodies, documentation.

**Related:** Schrute Test, Communication Rules.

**Usage:** "Apply Kevin's Law: describe what changed, not the process."

---

### Schrute Test

**Definition:** "Whenever I'm about to do something, I think: would an idiot do that? And if they would, I do not do that thing." — Dwight Schrute.

**Scope:** Modifying zdots, proceeding without verification, assuming confidence equals correctness, any action whose blast radius exceeds task scope.

**Response:** Stop. File an issue. Ask. Do not proceed.

**Related:** Kevin's Law, Communication Rules.

**Usage:** "Apply the Schrute Test before a destructive operation."

---

### Communication Rules

**Definition:** Standards for how to talk about zdots in conversations, PRs, commits, issues.

**Vocabulary:** Use exact terms from CONTEXT.md (Platform Service, not "service"; Seam, not "boundary").

**Audience:** Agents, humans, and future maintainers.

**Related:** Kevin's Law, Schrute Test, Glossary.

**Usage:** "In commit messages, use 'PHI Scrubber', not 'phi scrubber' or 'PHI scrubbing'."

---

## Cross-Cutting

### Registry

**Definition:** A centralized catalog of metadata and dispatch points.

**Examples:**
- Service Registry (`lib/svc-registry.bash`) — Platform Services, health probes
- PHI Pattern Registry (`etc/phi-patterns.yaml`) — sensitive patterns, redaction rules
- Job Registry (`lib/zdots/jobs/`) — job types, handlers

**Principle:** Single source of truth; no duplication.

**Usage:** "Add a service: one edit in the Service Registry."

---

### Invariant

**Definition:** A property that must always be true.

**Examples:**
- "PHI protection is unavailable" → hard failure (not silent degradation)
- "Session state is always captured" → audit trail preserved
- "Suppress-flagged patterns fail hard" → no partial output

**Scope:** Contracts, error handling, security.

**Usage:** "The invariant is: suppress-match always exits non-zero."