# Zdots Ontology — Concepts & Relationships

A structured hierarchy of zdots concepts, showing how they relate, depend on each other, and organize into domains.

---

## Top-Level Domains

```
ZDOTS
├── Platform Layer
│   ├── Services (Management, Control)
│   ├── Observability (Tracing, Metrics, Logging)
│   └── Configuration & State
├── Knowledge Layer
│   ├── Persistence (PostgreSQL-backed)
│   ├── Curation (Virtuous Loop)
│   └── AI Integration
├── Control Plane
│   ├── Orchestration (Workflows, Automation)
│   ├── Safety & Access (Actors, Alerts, Access Control)
│   └── Discovery & Introspection
└── Communication & Style
    ├── Vocabulary (Glossary, Ontology)
    ├── Principles (Kevin's Law, Schrute Test)
    └── Rules (Naming, Messaging)
```

---

## Platform Layer — Services

### Service Concept Hierarchy

```
Platform Service (abstract)
├── Core Service (required; blocks zdots on failure)
│   ├── llama (AI inference)
│   ├── whisper (transcription)
│   ├── otel-collector (observability)
│   ├── context-engine (knowledge persistence)
│   └── Worker (async job draining)
├── Cache Service (optional; graceful degradation)
│   ├── Redis (command analytics buffer; fallback SQLite)
│   └── Colima/Docker (VM for services)
└── Hosted Service (unrelated to zdots; zdots manages it)
    ├── wwworkremote (job search)
    └── Phalanx Duel (game management)
```

### Service Management

```
Service Lifecycle
├── Start — bring up a process
├── Stop — shut down a process
├── Restart — stop then start
├── Status — query current state
├── Health — liveness probe result
├── Logs — tail service log
└── Diag — full diagnostic (status + health + logs)

Service Registry (single source of truth)
├── Metadata (name, display name, endpoint, type, ctl script)
├── Health Probe (function name in svc-health.bash)
├── Launchd Label (macOS integration)
└── Lifecycle Verbs (start, stop, restart)

Accessors
├── zsvc resolve <alias>           — name resolution
├── zdots_svc_managed              — list controllable services
├── zdots_svc_state                — current state + PID
└── zdots_svc_healthy              — health probe result
```

### Observability Under Platform Layer

```
Observability Stack
├── Trace
│   ├── Trace ID (unique per request)
│   ├── Span (named unit of work within trace)
│   │   ├── Start/end time
│   │   ├── Status (OK, ERROR)
│   │   ├── Attributes (key=value)
│   │   └── Events (structured logs within span)
│   └── Propagation (via env var in zsh; manual in bash)
├── Metrics
│   ├── Counter (monotonic increase)
│   ├── Gauge (current value)
│   └── Histogram (distribution)
├── Logs
│   ├── Structured (JSON)
│   ├── Unstructured (text)
│   └── Redacted (PHI scrubbed at ingest)
└── Collector
    ├── otel-collector (aggregates traces/metrics)
    ├── OpenObserve (stores, queries)
    └── Query Interface (zdots-o2-query)
```

---

## Knowledge Layer

### Knowledge Concepts

```
Knowledge Base (PostgreSQL, local-only)
├── Session Residue (raw capture from sessions)
│   ├── Intent (what was the goal)
│   ├── Result (what happened)
│   ├── Summary (human-readable digest)
│   ├── Trace ID (links to execution trace)
│   └── Lifecycle (unprocessed → processed)
├── Lesson (curated atomic unit)
│   ├── Content (text)
│   ├── Context (optional background)
│   ├── Tags (searchable)
│   ├── Source (from Session Residue or authored)
│   └── Vector Embedding (for semantic search)
└── Methodology (synthesized principle)
    ├── Slug (stable key)
    ├── Title
    ├── Content
    ├── Tags
    └── Vector Embedding

Knowledge Vault (Obsidian, source of truth)
├── inbox/ (fast capture, unprocessed)
├── lessons/ (maps to lessons table)
├── methodologies/ (maps to methodologies table)
└── references/ (external sources)

Virtuous Loop (feedback mechanism)
├── Work (shell sessions, agent actions)
├── Capture (zdots-ctx capture → distill job)
│   ├── Normalize (strip artifacts)
│   ├── PHI Scrub (redact/suppress sensitive)
│   └── Distill (AI → intent/result/summary)
├── Curate (human review + promotion)
│   ├── Review Session Residue
│   ├── Promote to Lesson
│   └── Synthesize into Methodology
├── Infer (AI uses curated context)
│   └── zdots-ctx hydrate (load context blob for AI)
└── Loop (actions captured, fed back, improving signal)
```

### Job Queue (Async Processing)

```
Job (unit of work)
├── Type (kind of processing)
│   ├── embed (vector generation)
│   ├── distill (transcript → Lesson)
│   ├── docs_sync (Session Residue → maintained docs)
│   └── transcription (audio → text)
├── Payload (input data)
├── State Transition
│   ├── pending (enqueued, not yet claimed)
│   ├── running (claimed by Worker, in progress)
│   ├── complete (succeeded)
│   └── failed (error)
└── Claim Semantics (one job at a time via PL/pgSQL)

Worker (Core Service)
├── Lifecycle (launchd agent, KeepAlive + RunAtLoad)
├── Loop (claim → perform → sleep 5s)
├── Job Registry (job type → handler mapping)
├── Error Handling (stale jobs → clear-stale-jobs)
└── Observability (queue depth, job latency)
```

### AI Integration

```
AI Invocation (all inference via seam)
├── zdots_ai_infer_raw() — stdin → stdout (raw text)
│   ├── Gate check (mode + locality)
│   ├── Message Hygiene (normalize + PHI scrub)
│   ├── Submission (direct HTTP to llama.cpp)
│   └── Output parsing (raw text)
└── zdots_ai_distill() — stdin → stdout (JSON)
    ├── Calls zdots_ai_infer_raw internally
    ├── Requests JSON output
    └── Validates JSON parses

AI Boundary (safety enforcement)
├── Mode Check (ZDOTS_AI_MODE must be local)
├── Locality Check (endpoint must be loopback/RFC-1918)
├── Hard Failure (exits non-zero if violations)
└── Message Hygiene (PHI checked before submission)

Domain Router
├── zdots-ask --domain <tag>
├── Routes to model/prompt based on domain tags
└── Examples: ruby, python, shell, generic
```

---

## Control Plane — Orchestration

### Workflow System

```
Workflow (declarative job sequence)
├── Definition (.zdots/workflows/*.yaml)
│   ├── Name (identifier)
│   ├── Trigger (cron, webhook, manual, event)
│   ├── Steps (ordered sequence)
│   │   ├── Name
│   │   ├── Command (shell command to run)
│   │   ├── Timeout
│   │   ├── Error handling (continue, fail, notify)
│   │   └── Dependencies (depends_on: [other_step])
│   └── Observability (trace per run, status queryable)
├── Interface
│   ├── zdots workflow run <name>
│   ├── zdots workflow list
│   ├── zdots workflow status <name>
│   ├── zdots workflow validate <name>
│   └── zdots workflow delete <name>
└── Integration
    ├── Enqueues Jobs (if steps are job-enqueuing)
    ├── Captured as Session (subject to Virtuous Loop)
    └── Traces stored in observability system

Automation
├── Workflows (declarative, composable)
├── Scripts (imperative, portable, typed)
├── Cron (time-based triggers)
├── Webhooks (HTTP-based triggers)
└── Manual (user-initiated)
```

### Configuration & State

```
Configuration (all settings, single source of truth)
├── Environment Variables (.zdots.local, .zdots.env, .zdots.work)
│   ├── AI_MODE (local, cloud, none)
│   ├── ZDOTS_AI_ENDPOINT (default http://127.0.0.1:11500)
│   ├── CMD_ANALYTICS (1 or 0)
│   └── Other Knobs
├── Service Descriptors (Service Registry)
│   ├── Metadata (name, endpoint, type)
│   ├── Health Probe (function reference)
│   └── Lifecycle (start/stop scripts)
├── Schema Versions (Migrations)
│   ├── Database schema (PostgreSQL)
│   ├── Know Vault structure
│   └── Data format versions
├── Pattern Registries
│   ├── PHI Patterns (etc/phi-patterns.yaml)
│   └── Credential patterns (same)
├── Tool Configurations
│   ├── Claude Code (.claude/settings.json, .claude/settings.local.json)
│   ├── MCP Servers (.mcp.json)
│   └── Ruby config (Gemfile, bundler settings)
└── Validation (schema-based, discoverable)

Template / Templating
├── Service Templates (reusable service definitions)
├── Workflow Templates (reusable workflow definitions)
├── Config Templates (reusable configurations)
└── Environment Templates (full-system snapshots)

Environment (isolated zdots state)
├── Name (identifier)
├── Configuration (copy of all settings)
├── Services (parallel process tree)
├── Database (isolated PostgreSQL or SQLite)
├── Activation (ZDOTS_ENV env var)
└── Use Cases (testing, multi-workstation, CI/CD)
```

---

## Control Plane — Safety & Access

### Access Control Model (Speculative)

```
Actor (named principal)
├── Name (identifier)
├── Type (human, agent, service)
├── Role (researcher, deployer, auditor, admin)
├── Permissions (allow/deny list)
│   ├── Allow patterns (glob: "zdots-ctx query")
│   ├── Deny patterns (glob: "deny: zdots-ctx migrate")
│   └── Scope (local, remote, all)
└── Audit Trail (actions recorded)

Access Control
├── Definition (YAML role + permission model)
├── Enforcement (gate checks before each command)
├── Delegation (agents can request capabilities)
└── Compliance (audit trail for all actions)

Audit
├── Actor (who did it)
├── Action (what command)
├── Timestamp (when)
├── Result (success/failure)
├── Context (trace_id, session_id, if applicable)
└── Queryable via (zdots audit --actor <name> --last 1h)
```

### Alert System (Speculative)

```
Alert (condition-based notification + remediation)
├── Definition (.zdots/alerts/*.yaml)
│   ├── Name (identifier)
│   ├── Condition (predicate on system state)
│   │   ├── Service state (health != healthy)
│   │   ├── Metric threshold (queue_depth > 1000)
│   │   └── Custom checks (lua-based?)
│   ├── Threshold (duration before alert fires)
│   ├── Severity (critical, high, medium, low)
│   └── Actions (what to do)
│       ├── Notify (Slack, email, webhook)
│       ├── Auto-remediate (restart service, clear stale)
│       └── Escalate (ask council, page on-call)
├── Interface
│   ├── zdots alert list
│   ├── zdots alert silence <alert> --for <duration>
│   ├── zdots alert status <alert>
│   └── zdots alert test <alert>
└── Integration
    ├── Evaluated periodically (background task)
    ├── Fired alerts are observable events
    └── Actions enqueue workflows or jobs

Health & Capability
├── Health (service liveness)
│   ├── Probe (health-check function)
│   ├── Status (healthy, unhealthy, unknown)
│   └── Threshold (timeout, failure count)
└── Capability (advertised facility)
    ├── Name (does-ai-inference)
    ├── Type (operation, check, resource)
    ├── Requires (dependencies)
    └── Attestation (proof via health check)
```

---

## Control Plane — Discovery

### Introspection & Capability Discovery

```
Capability Discovery
├── Capability (advertised operation or facility)
│   ├── Name (does-ai-inference, has-embeddings)
│   ├── Type (operation, check, resource)
│   ├── Requires (dependencies: [llama, embeddings])
│   └── Attestation (health check to verify)
├── Interface
│   ├── zdots capability list (all)
│   ├── zdots capability check "name" (exists?)
│   ├── zdots capability query "service:llama" (what can I do with llama?)
│   └── zdots capability requires "does-ai-inference" (deps)
└── Use Cases
    ├── Agent introspection (am I capable of inference?)
    ├── Permission checks (can I invoke this?)
    └── Dependency resolution (what must start first?)

Command Discovery
├── Command Listing
│   ├── zdots command list (all commands)
│   ├── zdots command list --domain <tag> (by domain)
│   └── zdots command search "keyword"
├── Help
│   ├── zdots help <command>
│   ├── zdots help <concept> (e.g., "Workflow")
│   └── zdots help --all (full manual)
└── Structured Metadata
    ├── Command signature (name, args, options)
    ├── Short description
    ├── Long description (with examples)
    ├── Exit codes
    ├── Environment variables
    └── Related commands

Agent Discovery
├── Agent Listing
│   ├── zdots agent list (available agents)
│   ├── zdots agent info <name>
│   └── zdots agent capabilities <name>
├── Integration Points
│   ├── Pi (REPL, exploration)
│   ├── Aider (code editing)
│   ├── Claude Code (this session)
│   └── Haiku (fast inference)
└── Delegation Model (agents can request capabilities)
```

---

## Communication & Principles

### Style & Standards

```
Kevin's Law (Minimal, exact, code-first)
├── Application
│   ├── Comments (only WHY; not WHAT)
│   ├── Commit messages (verb-first, why the change)
│   ├── PR descriptions (summary, test plan, motivation)
│   ├── Issues (specific, actionable, reproduced)
│   └── Documentation (code first, prose only when necessary)
└── Spirit (no filler, no hedging, no pleasantries)

Schrute Test (Verify before acting)
├── Before any action, ask: "Would an idiot do that?"
├── Applies to
│   ├── Modifying zdots infrastructure
│   ├── Proceeding without verification
│   ├── Destructive operations (rm, reset, delete)
│   └── Actions with unknown blast radius
└── Response (Stop. File an issue. Ask. Do not proceed.)

Vocabulary & Naming
├── Use exact terms from CONTEXT.md
│   ├── Platform Service (not "service")
│   ├── Seam (not "boundary")
│   ├── Knowledge Layer (not "Intelligence Suite")
│   ├── Lesson (not "note" or "doc")
│   └── Session Residue (not "capture" or "transcript")
├── Consistency across
│   ├── Code (variable names, function names)
│   ├── Commit messages
│   ├── Issues & PRs
│   ├── Documentation
│   └── Agent conversations
└── Antonyms (to avoid)
    ├── "service" (ambiguous; use full term)
    ├── "boundary" (use "seam")
    ├── "component" (use "module")
    ├── "Intelligence Suite" (use "Knowledge Layer")

Communication Rules
├── Audience (agents, humans, future maintainers)
├── Context (always explain "why")
├── Precision (use domain terminology)
├── Traceability (link to tickets, traces, PRs)
└── Auditability (clear decision trail)

ADR (Architecture Decision Records)
├── Format (Context, Decision, Consequences, Revisit)
├── When to write (load-bearing decisions, rejected alternatives)
├── Storage (docs/adr/)
├── Audience (future architects, agents revisiting the same friction)
└── Examples (ADR-0001: nginx not in CLI path; ADR-0002: PHI Scrubber in Go)
```

---

## Cross-Cutting Patterns

### The Seam Pattern

```
Seam (place where behavior can be altered without editing in place)
├── Service Registry Seam
│   ├── Interface (metadata + health-check dispatch)
│   ├── Adapters (individual *-ctl scripts, platform ctl)
│   └── Single Source of Truth (lib/svc-registry.bash)
├── Message Hygiene Seam
│   ├── Interface (stdin → hygienized stdout)
│   ├── Stages (normalize, PHI scrub, enforced in order)
│   └── Single Source of Truth (lib/message_hygiene.bash)
├── AI Invocation Seam
│   ├── Interface (gate, hygiene, submission, parsing)
│   ├── Callers (ai-query, zdots-ask, Ruby pipeline)
│   └── Single Source of Truth (lib/ai-invoke.bash)
└── PHI Scrubber Seam
    ├── Interface (redact mode, suppress mode, initialization)
    ├── Adapters (bash wrapper, Ruby wrapper, both calling Go binary)
    └── Single Source of Truth (cmd/zdots-phi-scrub/main.go)
```

### The Registry Pattern

```
Registry (centralized catalog of metadata + dispatch)
├── Service Registry (lib/svc-registry.bash)
│   ├── Metadata (name, endpoint, type, ctl, label)
│   ├── Health Dispatch (function name lookup)
│   └── Callers (zsvc, zdots-ctl)
├── PHI Pattern Registry (etc/phi-patterns.yaml)
│   ├── Metadata (name, regex, replace, suppress flag)
│   ├── Compilation (sed args, suppress pattern OR)
│   └── Callers (bash scrubber, Ruby scrubber, Go binary)
├── Job Registry (lib/zdots/jobs/)
│   ├── Metadata (job type → handler class mapping)
│   ├── Dispatch (claim_next_job → class.new.perform)
│   └── Callers (Worker service)
└── Principle (Single Source of Truth; no duplication)
```

### The Invariant Pattern

```
Invariant (property that must always be true)
├── PHI Protection
│   ├── "If PHI unavailable → hard failure (exit 1, no output)"
│   └── "If suppress-match → hard failure (no partial output)"
├── Message Hygiene
│   ├── "Normalize always runs before PHI scrub"
│   └── "PHI scrub always runs before persistence/inference"
├── Service State
│   ├── "Core Service down → zdots-ctl check fails with exit 1"
│   └── "Cache Service down → graceful fallback (not error)"
├── Knowledge Base
│   ├── "All actions captured in audit trail"
│   └── "Capture + curation closes the Virtuous Loop"
└── Enforcement (encoded in code, tests, and documentation)
```

---

## Dependency Graph (What Depends On What)

```
Platform Layer
  ├── Service Registry
  │   └── (no dependencies)
  ├── Service Lifecycle (depends on Service Registry)
  │   └── Observability (Health, Status, Logs)
  └── Observability
      ├── OTEL Collector
      ├── Tracing (Trace ID, Span)
      └── Metrics (Counters, Gauges)

Knowledge Layer
  ├── Message Hygiene Pipeline
  │   ├── Normalize (no external deps)
  │   └── PHI Scrubber (depends on PHI Pattern Registry)
  ├── PHI Pattern Registry (etc/phi-patterns.yaml)
  │   └── Single source of truth
  ├── Knowledge Base (PostgreSQL)
  │   ├── Schema (migrations)
  │   └── Data (Lessons, Methodologies, Session Residue)
  ├── Virtuous Loop
  │   ├── Capture (depends on Message Hygiene)
  │   ├── Distill (depends on AI Invocation)
  │   ├── Worker (depends on Job Queue)
  │   └── Curate (human-driven, uses Knowledge Vault)
  └── AI Integration
      ├── AI Invocation (depends on AI Boundary, Message Hygiene)
      ├── AI Boundary (depends on ZDOTS_AI_MODE env var)
      └── Domain Router (depends on AI Invocation)

Control Plane
  ├── Workflow System
  │   ├── Depends on Service Lifecycle, Job Queue, Observability
  │   └── Can enqueue Jobs
  ├── Configuration System
  │   ├── Depends on Validation schema
  │   └── Read/written by all layers
  ├── Access Control (speculative)
  │   └── Depends on Actor, Audit
  ├── Alert System (speculative)
  │   └── Depends on Health, Observability, Workflow Actions
  └── Scripting (speculative)
      ├── Depends on Command Discovery
      └── Can enqueue Workflows or Jobs

Communication & Style
  ├── Vocabulary (Glossary, Ontology)
  │   └── Used by all layers and agents
  ├── Principles (Kevin's Law, Schrute Test)
  │   └── Enforced in code review, decisions
  └── ADRs (Architecture Decision Records)
      └── Document decisions, prevent re-litigation
```

---

## Conceptual Layers

```
Semantic Layers (what matters at each level)

Layer 5: Human Agents & Operations
  └── Workflows, Automation, Alerts, Governance
      └── (Composed from Layer 4)

Layer 4: Control Plane & DSL
  └── Workflow, Template, Environment, Configuration, Capability
      └── (Composed from Layer 3)

Layer 3: Knowledge & AI
  └── Lessons, Methodologies, Virtuous Loop, Jobs, Inference
      └── (Stored in Layer 2, orchestrated by Layer 1)

Layer 2: Persistence
  └── PostgreSQL (Knowledge Base), Redis (Analytics Buffer), Filesystem (Config)
      └── (Exposed via Layer 1 interfaces)

Layer 1: Platform Services
  └── llama (inference), whisper (transcription), otel-collector (observability), context-engine
      └── (Managed by Unix layer; launchd, process, IPC)

Layer 0: Unix/OS
  └── Processes, signals, sockets, permissions, Unified Logging
      └── (Substrate; not owned by zdots)
```