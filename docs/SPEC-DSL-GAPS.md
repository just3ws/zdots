# Zdots Speculative DSL — Technical Specs for 10 Gaps

Detailed specifications for the 10 critical gaps identified in the DSL matrix. Each spec includes: problem statement, proposed syntax, benefits, implementation notes, and open design questions.

---

## Gap 1: Unified Configuration System

### Problem

Configuration is currently scattered across multiple file formats with no schema validation, versioning, or templating:
- `.zdots.local`, `.zdots.env` (bash)
- `.claude/settings.json`, `.claude/settings.local.json` (JSON)
- `etc/phi-patterns.yaml` (YAML, specific to PHI)
- SQL migrations (schema versions)
- Plist files (launchd)
- Hardcoded defaults in scripts

**Impact:** Discoverable, hard to validate, hard to template, hard to migrate.

### Proposed Solution: Config DSL

#### Unified Config File Format

```yaml
# ~/.zdots/config.yaml — single source of truth for all settings

version: "2026-06-12"
schema_version: "1.0"

# AI Configuration
ai:
  mode: local                    # local | cloud | none
  endpoint: http://127.0.0.1:11500
  embed_endpoint: http://127.0.0.1:11501
  model: qwen3-14b
  timeout_seconds: 30
  max_retries: 3

# Analytics & Capture
analytics:
  enabled: true
  buffer:
    primary: redis             # redis | sqlite
    fallback: sqlite
    redis_host: 127.0.0.1
    redis_port: 6379
  command_history: true
  history_retention_days: 90

# Database & Persistence
database:
  primary: postgresql
  url: postgresql://zdots_rw@localhost/my
  encryption_key: "${ZDOTS_DB_ENCRYPTION_KEY}"  # from Keychain
  migrations_path: db/migrations

# Services
services:
  llama:
    enabled: true
    port: 11500
    model: qwen3-14b
  whisper:
    enabled: false
    port: 8000
  otel_collector:
    enabled: true
    endpoint: http://127.0.0.1:4317

# Knowledge Layer
knowledge:
  vault_path: ~/my/knowledge
  auto_sync: true
  auto_capture: true
  vectorstore: pgvector
  embedding_model: bge-base

# Observability
observability:
  enabled: true
  exporter: otlp_http
  endpoint: http://127.0.0.1:4317
  batch_size: 512
  flush_interval_ms: 5000

# Security & PHI
security:
  phi_patterns_file: etc/phi-patterns.yaml
  enable_phi_scrubbing: true
  fail_on_uninitialized: true
  audit_enabled: true

# Profiles (machine-specific overrides)
profiles:
  work:
    ai:
      mode: local
    analytics:
      enabled: false         # no analytics on work machine
    security:
      audit_enabled: true
  home:
    ai:
      mode: local
    analytics:
      enabled: true
```

#### CLI Interface

```bash
# Get a setting
zdots config get ai.mode
zdots config get ai.endpoint
zdots config get database.url

# Set a setting
zdots config set ai.mode local
zdots config set analytics.enabled false

# Validate all config
zdots config validate
zdots config validate --strict   # fail on unknown keys

# Validate against schema
zdots config validate --schema docs/config-schema.json

# Apply a template
zdots config apply --from templates/minimal.yaml
zdots config apply --from templates/work-machine.yaml

# Export current state
zdots config export > backup-2026-06-12.yaml

# List all settings
zdots config list
zdots config list --profile work

# Watch for changes
zdots config watch                # stream changes as they happen

# Reset to defaults
zdots config reset ai.mode
zdots config reset --all
```

#### Design: Schema & Validation

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Zdots Configuration",
  "type": "object",
  "required": ["version", "ai", "database"],
  "properties": {
    "version": { "type": "string", "pattern": "^\\d{4}-\\d{2}-\\d{2}$" },
    "schema_version": { "type": "string" },
    "ai": {
      "type": "object",
      "properties": {
        "mode": { "enum": ["local", "cloud", "none"] },
        "endpoint": { "type": "string", "format": "uri" },
        "timeout_seconds": { "type": "integer", "minimum": 1, "maximum": 300 },
        "model": { "type": "string" }
      },
      "required": ["mode"]
    },
    "analytics": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean" },
        "buffer": {
          "type": "object",
          "properties": {
            "primary": { "enum": ["redis", "sqlite"] },
            "fallback": { "enum": ["sqlite"] }
          }
        }
      }
    }
  }
}
```

#### Implementation Notes

1. **Parser:** Use YAML (human-editable) with JSON Schema validation
2. **Storage:** `~/.zdots/config.yaml` (single file, versioned in git as `.zdots/config.default.yaml`)
3. **Overrides:** Machine-local `.zdots/config.local.yaml` (gitignored) for secrets, per-machine tuning
4. **Lookup:** Merge defaults + machine overrides + active profile at startup
5. **Secrets:** Support `${VAR_NAME}` substitution (resolved from environment or Keychain)
6. **Validation:** Fail hard on startup if config is invalid (not graceful degradation)
7. **Migration:** Provide converter script `.zdots.local` → `config.yaml`

#### Benefits

- **Discoverable:** `zdots config list` shows all available settings
- **Validated:** Schema enforces types, ranges, enums
- **Typed:** Tools can introspect schema and provide completion
- **Templated:** Reusable profiles (work, home, CI)
- **Auditable:** Single file; easy to diff, version, review
- **Migrable:** Schema versioning allows non-breaking changes

#### Open Questions

1. How do we handle _generated_ settings (e.g., generated launchd labels)?
2. How do we handle _read-only_ settings (e.g., current state, diagnostics)?
3. Should profiles be separate files or sections in one file?
4. How do we hot-reload config without restarting services?

---

## Gap 2: Workflow & Pipeline System

### Problem

Multi-step orchestration currently done via shell scripts (hard to test, port, audit) or manual invocation. No declarative, observable pipeline language.

### Proposed Solution: Workflow DSL

#### Workflow Definition Format

```yaml
# ~/.zdots/workflows/daily-sync.yaml

apiVersion: zdots.io/v1
kind: Workflow
metadata:
  name: daily_sync
  description: "Daily sync of knowledge base and analytics"
  tags: [daily, sync, knowledge]

spec:
  # When to run
  trigger:
    type: cron
    schedule: "0 9 * * *"      # 9 AM daily
    timezone: America/Los_Angeles

  # Configuration for this workflow
  config:
    timeout: 30m               # max time for entire workflow
    on_failure: notify         # what to do if any step fails
    parallelism: 2             # max concurrent steps
    retry:
      max_attempts: 3
      backoff_seconds: 30

  # Execution steps
  steps:
    - name: health_check
      description: "Verify platform is healthy"
      command: zdots-ctl check
      timeout: 1m
      on_failure: fail         # stop workflow on failure

    - name: sync_history
      description: "Drain analytics buffer to PostgreSQL"
      command: zdots-ctx sync-history --dry-run
      timeout: 5m
      depends_on: [health_check]
      retry:
        max_attempts: 3
        backoff_seconds: 30

    - name: reindex_embeddings
      description: "Generate embeddings for new lessons"
      command: zdots-brain reindex-embeddings
      timeout: 10m
      depends_on: [sync_history]
      on_failure: continue      # warn but don't stop

    - name: notify_success
      description: "Notify on completion"
      command: zsynod request "Daily sync completed at $(date)"
      timeout: 30s
      depends_on: [reindex_embeddings]
      only_if: "previous_steps_succeeded"

    - name: notify_failure
      description: "Alert on failure"
      command: zsynod alert "Daily sync FAILED"
      timeout: 30s
      only_if: "any_step_failed"

  # Notifications
  notifications:
    - type: slack
      channel: "#ops"
      on: [success, failure]
    - type: otel
      severity: [info, error]

  # Observability
  observability:
    trace_prefix: "workflow.daily_sync"
    emit_metrics: true
    log_level: info
```

#### CLI Interface

```bash
# List workflows
zdots workflow list
zdots workflow list --enabled       # only active workflows
zdots workflow list --trigger cron  # by trigger type

# View workflow definition
zdots workflow show daily_sync
zdots workflow show daily_sync --json

# Run a workflow
zdots workflow run daily_sync
zdots workflow run daily_sync --dry-run        # preview without executing
zdots workflow run daily_sync --skip-step health_check  # skip certain steps

# Schedule a workflow
zdots workflow schedule daily_sync --trigger "cron 0 9 * * *"
zdots workflow unschedule daily_sync

# View execution history
zdots workflow history daily_sync
zdots workflow history daily_sync --last 10
zdots workflow history daily_sync --last 7d    # last 7 days

# View current execution
zdots workflow status daily_sync                # last run status
zdots workflow logs daily_sync --last 1h       # logs from last run
zdots workflow watch daily_sync                # stream current run

# Validate a workflow
zdots workflow validate daily_sync
zdots workflow test daily_sync                 # dry-run with fixtures

# Edit a workflow
zdots workflow edit daily_sync                 # opens editor
zdots workflow apply --from new_workflow.yaml

# Delete a workflow
zdots workflow delete daily_sync --confirm
```

#### Design: Step Execution

```
Step Lifecycle:
  pending (enqueued)
    ↓
  waiting (dependencies not met)
    ↓
  ready (dependencies satisfied)
    ↓
  running (command executing)
    ↓
  complete (exit 0) | failed (exit non-zero)
    ↓
  notified (notifications sent)

Dependency Resolution:
  - DAG topological sort
  - Parallel steps (no dependencies) run concurrently up to parallelism limit
  - Step failure triggers on_failure action

Error Handling:
  - fail: stop workflow
  - continue: warn but proceed
  - notify: send notification and stop
  - retry: exponential backoff, max_attempts limit
```

#### Implementation Notes

1. **Parser:** YAML with JSON Schema validation
2. **Storage:** `~/.zdots/workflows/*.yaml` (one file per workflow)
3. **Execution:** Enqueue as Job; Worker processes as special workflow-type job
4. **State:** Track in PostgreSQL (workflow_runs table)
5. **Observability:** Each step is a span; entire workflow is a trace
6. **Idempotency:** Steps must be idempotent (run twice = same result)
7. **Secrets:** Support `${VAR_NAME}` substitution (from environment or Keychain)

#### Benefits

- **Declarative:** Easier to read, review, test than shell scripts
- **Observable:** Each workflow run is a trace; queryable, debuggable
- **Composable:** Workflows can call other workflows (nested)
- **Auditable:** Execution history stored; immutable record
- **Portable:** YAML is portable; same workflow on any machine
- **Testable:** `--dry-run` and `--test` modes for validation

#### Open Questions

1. Should workflows be able to branch (if/else)?
2. Should workflows be composable (workflow calling workflow)?
3. How do we handle secrets (env vars, Keychain)?
4. Should there be a feedback loop (metrics → trigger new workflow)?

---

## Gap 3: Alert & Threshold System

### Problem

No declarative way to define alerts or escalation. Health checks are manual; no auto-remediation; no observability thresholds.

### Proposed Solution: Alert DSL

#### Alert Definition Format

```yaml
# ~/.zdots/alerts/llama-unhealthy.yaml

apiVersion: zdots.io/v1
kind: Alert
metadata:
  name: llama_unhealthy
  description: "Alert when AI inference is unavailable"
  severity: critical
  tags: [ai, critical]

spec:
  # Condition: when to fire
  condition:
    type: service_health
    service: llama
    check: not_healthy
    duration: 1m              # alert if unhealthy for > 1 min

  # Alternative: metric-based condition
  # condition:
  #   type: metric_threshold
  #   metric: llama_response_time_ms
  #   operator: ">"
  #   threshold: 5000
  #   duration: 5m
  #   aggregation: p95        # 95th percentile

  # What to do when alert fires
  actions:
    # Immediate actions
    - type: notify
      channel: slack
      message: "CRITICAL: AI inference is down!"
      mentions: ["@oncall"]
      rate_limit: 5m           # don't spam; max once per 5 min

    - type: notify
      channel: email
      recipients: ["ops@example.com"]

    # Auto-remediation (if safe)
    - type: execute_action
      name: restart_llama
      command: zsvc restart llama
      confirm: true            # require human approval first
      timeout: 2m

    # Escalation
    - type: execute_action
      name: escalate_to_council
      command: zsynod request "Critical alert: llama_unhealthy"
      confirm: false

    # Fire another alert (chain)
    - type: fire_alert
      alert: llama_unhealthy_escalated

  # When NOT to alert (suppress noisy alerts)
  suppression:
    - type: during_maintenance
      windows:
        - name: weekly_backup
          schedule: "sun 2-3 *"
    - type: max_one_per
      duration: 15m

  # Recovery notification
  recovery_action:
    type: notify
    channel: slack
    message: "RESOLVED: AI inference is back online"

  # Observability
  observability:
    trace_event: "alert.llama_unhealthy"
    emit_metric: true
```

#### CLI Interface

```bash
# List alerts
zdots alert list
zdots alert list --severity critical  # by severity
zdots alert list --status firing      # currently firing

# View alert definition
zdots alert show llama_unhealthy
zdots alert show llama_unhealthy --json

# View alert status
zdots alert status llama_unhealthy        # current state
zdots alert history llama_unhealthy       # fire history
zdots alert history llama_unhealthy --last 7d

# Silence an alert (temporary)
zdots alert silence llama_unhealthy --for 1h
zdots alert silence llama_unhealthy --for 1h --reason "maintenance"
zdots alert unsilence llama_unhealthy

# Test an alert
zdots alert test llama_unhealthy           # dry-run (don't fire actions)
zdots alert test llama_unhealthy --action-mode notify_only

# Acknowledge a firing alert
zdots alert ack llama_unhealthy            # mark as seen
zdots alert ack llama_unhealthy --reason "investigating"

# Manually fire/resolve
zdots alert fire llama_unhealthy
zdots alert resolve llama_unhealthy

# Edit an alert
zdots alert edit llama_unhealthy
zdots alert apply --from new_alert.yaml

# Delete an alert
zdots alert delete llama_unhealthy --confirm

# Validation
zdots alert validate llama_unhealthy
zdots alert validate --all                 # validate all alerts
```

#### Design: Alert Evaluation

```
Alert Evaluation Loop (background task, runs every 1 min):
  1. For each alert:
     a. Check suppression windows (skip if in maintenance)
     b. Evaluate condition (type: service_health, metric_threshold, custom_check)
     c. Track state (not_firing → firing → fired)
     d. On state change:
        - Fire → execute actions
        - Firing (repeated) → check rate limiting, may suppress
        - Fired → execute recovery_action

Condition Types:
  - service_health: zdots_svc_healthy() + duration
  - metric_threshold: query observability backend (OpenObserve)
  - custom_check: run a shell command, check exit code
  - log_pattern: grep observability logs for pattern

Action Types:
  - notify: Slack, email, webhook, OTEL event
  - execute_action: run a command (with optional confirmation)
  - fire_alert: trigger another alert (chaining)
  - create_ticket: create issue in tracker (integration)
```

#### Implementation Notes

1. **Parser:** YAML with JSON Schema validation
2. **Storage:** `~/.zdots/alerts/*.yaml` (one file per alert)
3. **Evaluation:** Background task; runs every 1 min
4. **State:** Persistent in PostgreSQL (alerts table, state machine)
5. **Notification:** Via zdots notification bus (slack, email, webhook)
6. **Idempotency:** Actions must be idempotent (safe to run multiple times)
7. **Confirmation:** Actions with `confirm: true` require human approval

#### Benefits

- **Declarative:** Self-documenting; easy to audit and review
- **Observable:** Alert history and state visible
- **Actionable:** Can auto-remediate or escalate
- **Tunable:** Suppress false positives, adjust thresholds
- **Composable:** Alerts can chain (fire other alerts)

#### Open Questions

1. Should alerts be able to look at metrics/traces (integration with OpenObserve)?
2. Should there be a feedback loop (metric trend → adjust threshold)?
3. How do we handle alert fatigue (rate limiting, deduplication)?
4. Should confirmation be via Slack button or only CLI?

---

## Gap 4: Access Control & Multi-Actor Model

### Problem

Currently all-or-nothing: agents have full access or none. No way to define roles, permissions, delegation, or audit trail for multi-agent environments.

### Proposed Solution: Access Control DSL

#### Access Control Definition

```yaml
# ~/.zdots/access-control.yaml

apiVersion: zdots.io/v1
kind: AccessControl
metadata:
  version: "2026-06-12"

roles:
  # Researcher role: can read, learn, but not alter core
  researcher:
    description: "Interactive exploration and learning"
    permissions:
      - "zdots-ctx query"
      - "zdots-ctx hydrate"
      - "zdots-ctx capture"             # can capture sessions
      - "zdots-ask --domain *"
      - "zdots-ask --explain"
      - "pi-*"                          # can use Pi agent
      - deny: "zdots-ctx migrate"       # cannot alter schema
      - deny: "zsvc stop"               # cannot stop services
      - deny: "zdots config set"        # cannot change config

  # Deployer role: full control of services, but not knowledge
  deployer:
    description: "Service deployment and operational control"
    permissions:
      - "zsvc *"                        # full service control
      - "zdots-ctl *"                   # full platform control
      - "zdots-ctx migrate"             # can run migrations
      - "zdots-ctx rotate-creds"        # can rotate passwords
      - deny: "zdots-ctx query"         # cannot read knowledge
      - deny: "zdots-ctx capture"       # cannot capture

  # Auditor role: read-only access
  auditor:
    description: "Read-only access for compliance"
    permissions:
      - "zdots-ctx query --read-only"
      - "zdots audit --history *"
      - "zdots-ctl status"
      - "zdots-ctl check"
      - deny: "zdots-ctx hydrate"       # no AI inference context
      - deny: "zdots config set"

  # Admin role: full access
  admin:
    description: "Full access to all zdots operations"
    permissions:
      - "*"

# Actor definitions (agents, services, humans)
actors:
  - name: pi-agent
    type: agent
    role: researcher
    description: "Pi (interactive exploration)"
    identity:
      method: api_key              # authenticated via API key
      endpoint: http://pi.local

  - name: aider-agent
    type: agent
    role: researcher
    description: "Aider (code editing)"
    identity:
      method: api_key
      endpoint: http://localhost:8000

  - name: deploy-bot
    type: service
    role: deployer
    description: "Automated deployment service"
    identity:
      method: mtls                 # mutual TLS
      cert_fingerprint: "sha256:abc123..."

  - name: mike
    type: human
    role: admin
    description: "Mike (operator)"
    identity:
      method: unix_user            # Unix user identity
      username: mike

# Delegation rules (who can delegate to whom)
delegation:
  - from_role: admin
    to_actor: pi-agent
    capabilities: ["zdots-ask"]
    expiration: 1h

# Audit trail (immutable log of all access)
# Stored in PostgreSQL; queried via 'zdots audit' command
audit_config:
  enabled: true
  log_level: all                   # log all actions
  retention_days: 90
```

#### CLI Interface

```bash
# List actors
zdots actor list
zdots actor list --role researcher  # by role

# View actor details
zdots actor show pi-agent
zdots actor show pi-agent --json

# Add/remove actors
zdots actor add my-new-agent --role researcher --identity api_key
zdots actor remove my-new-agent --confirm

# Check permission
zdots actor check permission pi-agent "zdots-ctx query"
zdots actor check permission pi-agent "zdots-ctx migrate"  # should deny

# Delegate capability (temporary)
zdots actor delegate to pi-agent capability zdots-ask --for 1h
zdots actor revoke delegation pi-agent zdots-ask

# View audit trail
zdots audit --actor pi-agent                     # actions by actor
zdots audit --action "zdots-ctx migrate"         # actions of type
zdots audit --last 1h                            # last hour
zdots audit --between "2026-06-01" "2026-06-02"
zdots audit --export > audit-export.csv          # export for analysis

# Access policies
zdots access-control show
zdots access-control validate
zdots access-control apply --from new-policy.yaml
```

#### Design: Permission Model

```
Permission Syntax:
  - "command" — exact match (e.g., "zdots-ctx query")
  - "command *" — all subcommands (e.g., "zsvc *" → start, stop, restart, etc.)
  - "command --flag" — specific flag (e.g., "zdots config set" with flag restrictions)
  - "deny: command" — explicit deny (overrides allow)

Permission Evaluation:
  1. Check if action matches deny list → DENY
  2. Check if action matches allow list → ALLOW
  3. Default → DENY (secure-by-default)

Action Tracking:
  - Every command execution logged with: actor, command, args, exit code, timestamp, trace_id
  - Stored immutably in PostgreSQL
  - Queryable via 'zdots audit'
```

#### Implementation Notes

1. **Storage:** `~/.zdots/access-control.yaml`
2. **Validation:** Enforced at command gate (before execution)
3. **Audit:** Immutable log in PostgreSQL, append-only
4. **Identity:** Support Unix user, API key, mTLS, OAuth (extensible)
5. **Enforcement:** Fail hard if permission denied (exit 1, no execution)
6. **Delegation:** Temporary, revocable, logged

#### Benefits

- **Multi-agent safe:** Each agent has minimal required permissions
- **Auditable:** Complete log of who did what, when
- **Flexible:** Easy to add new roles, delegation, exceptions
- **Typed:** Schema validates permissions, prevents typos
- **Non-repudiable:** Immutable audit trail

#### Open Questions

1. Should permissions be resource-based (e.g., "can access lesson #123")?
2. Should there be time-based policies (allow only during business hours)?
3. Should delegation require confirmation from the delegated actor?
4. How do we handle emergency access (break-glass)?

---

## Gap 5: Template & Templating System

### Problem

Hard to reproduce configurations, workflows, and service setups across machines. Copy-paste and manual edits error-prone.

### Proposed Solution: Template System

#### Template Format

```yaml
# ~/.zdots/templates/work-machine-minimal.yaml

apiVersion: zdots.io/v1
kind: Template
metadata:
  name: work-machine-minimal
  description: "Minimal work-machine setup: local AI, no analytics"
  version: "1.0.0"
  author: "Mike"
  tags: [work, minimal]

spec:
  # Parameters (user-supplied during apply)
  parameters:
    - name: ai_model
      type: string
      default: qwen3-14b
      description: "AI model to use"
    - name: enable_transcription
      type: boolean
      default: false
      description: "Enable transcription service"

  # Configuration to apply
  config:
    version: "2026-06-12"
    ai:
      mode: local
      model: "${ai_model}"
    analytics:
      enabled: false             # no analytics on work machine
    services:
      llama:
        enabled: true
      whisper:
        enabled: "${enable_transcription}"
      otel_collector:
        enabled: true

  # Workflows to create
  workflows:
    - name: daily-sync
      description: "Daily knowledge sync"
      yaml: |
        apiVersion: zdots.io/v1
        kind: Workflow
        metadata:
          name: daily_sync
        spec:
          trigger:
            type: cron
            schedule: "0 9 * * *"
          steps:
            - name: health_check
              command: zdots-ctl check
              timeout: 1m

  # Alerts to create
  alerts:
    - name: llama-unhealthy
      description: "Alert if AI is down"
      yaml: |
        apiVersion: zdots.io/v1
        kind: Alert
        metadata:
          name: llama_unhealthy
        spec:
          condition:
            type: service_health
            service: llama
          actions:
            - type: notify
              channel: slack
              message: "CRITICAL: AI is down"

  # Access control policy
  access_control:
    roles:
      researcher:
        permissions:
          - "zdots-ctx query"
          - "zdots-ask"

  # Post-apply steps (optional)
  post_apply:
    - name: init_ai
      command: zdots-phi-scrub --init
      description: "Initialize PHI scrubber"
    - name: start_services
      command: zdots-ctl up
      description: "Bring up all services"
```

#### CLI Interface

```bash
# List available templates
zdots template list
zdots template list --tag work       # by tag
zdots template search "minimal"      # search by name/description

# View template details
zdots template show work-machine-minimal
zdots template show work-machine-minimal --json

# Apply a template (interactive)
zdots template apply work-machine-minimal
# Prompts for: ai_model, enable_transcription

# Apply with parameters
zdots template apply work-machine-minimal --set ai_model=qwen3-32b --set enable_transcription=true

# Apply with defaults (non-interactive)
zdots template apply work-machine-minimal --use-defaults

# Preview what would be applied
zdots template apply work-machine-minimal --dry-run

# Export current state as template
zdots template export > my-current-setup.yaml
zdots template export --tag mysetup

# Compose templates (layer multiple)
zdots template apply base.yaml && zdots template apply customizations.yaml

# List installed artifacts from template
zdots template status work-machine-minimal

# Revert template
zdots template revert work-machine-minimal --confirm

# Create custom template
zdots template create my-template        # interactive wizard
zdots template edit my-template          # edit in $EDITOR
```

#### Design: Template Composition

```
Template Composition:
  1. Load base template (e.g., work-machine-minimal)
  2. Prompt for parameters (or use --set / --use-defaults)
  3. Expand variables (${param_name})
  4. Apply config changes (merge with existing)
  5. Create workflows, alerts, policies
  6. Run post_apply steps
  7. Record template + parameters in history

Idempotency:
  - Applying same template twice should be safe
  - Config merges (not replaces)
  - Workflows are created if not exist, updated if exist
```

#### Implementation Notes

1. **Storage:** `~/.zdots/templates/*.yaml`
2. **Parameterization:** `${param_name}` substitution
3. **Validation:** Schema validates template definition
4. **History:** Track which templates were applied, in what order
5. **Revert:** Optional rollback (if config is versioned)
6. **Composition:** Support layering templates (base + overrides)

#### Benefits

- **Reproducible:** Same template = same setup
- **Discoverable:** `zdots template list` shows options
- **Parameterized:** Customize without editing template
- **Testable:** Can apply in isolated environment first
- **Auditable:** Template + parameters recorded

#### Open Questions

1. Should templates support conditionals (if/else)?
2. Should templates be able to reference other templates?
3. How do we handle secrets in templates (Keychain integration)?
4. Should there be a rollback/version history of template applications?

---

## Gap 6: Schema Versioning & Data Migrations

### Problem

Migrations are ad-hoc; no unified DSL for versioning configs, schemas, and data. Hard to track what version a machine is on; hard to roll back.

### Proposed Solution: Schema & Migration DSL

```yaml
# ~/.zdots/schema-version.yaml — global version marker

current_version: "2026-06-12"
migrations_applied:
  - version: "2026-06-01"
    description: "Add vectorstore schema"
    applied_at: "2026-06-01T09:00:00Z"
    applied_by: mike
    status: success
  - version: "2026-05-15"
    description: "Rotate database credentials"
    applied_at: "2026-05-15T14:30:00Z"
    applied_by: system
    status: success

# db/migrations/20260601_add_vectorstore.yaml

apiVersion: zdots.io/v1
kind: Migration
metadata:
  version: "2026-06-01"
  description: "Add vectorstore schema and tables"
  author: "Mike"
  applied_by: "system"

spec:
  # Database changes
  database:
    - type: sql
      up: |
        CREATE EXTENSION IF NOT EXISTS pgvector;
        CREATE TABLE IF NOT EXISTS embeddings (
          id SERIAL PRIMARY KEY,
          lesson_id INTEGER REFERENCES lessons(id),
          embedding vector(384),
          created_at TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX idx_embeddings_lesson ON embeddings(lesson_id);
      down: |
        DROP TABLE IF EXISTS embeddings CASCADE;
        DROP EXTENSION IF NOT EXISTS pgvector;

  # Config changes
  config:
    changes:
      - key: "knowledge.vectorstore"
        from: null
        to: "pgvector"
      - key: "knowledge.embedding_model"
        from: null
        to: "bge-base"

  # Service dependencies
  requires:
    - service: context-engine
      version: "1.2.0"

  # Post-migration steps
  post_migration:
    - name: reindex_embeddings
      command: zdots-brain reindex-embeddings --all
      description: "Generate embeddings for existing lessons"

  # Validation
  validation:
    checks:
      - query: "SELECT COUNT(*) FROM embeddings"
        description: "Table created"
    timeout_seconds: 300

  # Rollback instructions
  rollback:
    instructions: |
      1. Delete all new embeddings
      2. Drop pgvector extension
      3. Revert config changes

  # Breaking changes (warn user)
  breaking_changes:
    - description: "pgvector required for inference"
      mitigation: "Automatically installed; no action needed"
```

#### CLI Interface

```bash
# Check current version
zdots schema status
# Output: Current version: 2026-06-12 (applied 10 minutes ago)

# List available migrations
zdots schema list-migrations
zdots schema list-migrations --pending    # not yet applied

# Apply pending migrations
zdots schema migrate                      # apply all pending
zdots schema migrate --to 2026-06-01      # migrate to specific version

# Preview migrations (dry-run)
zdots schema migrate --dry-run

# Rollback to previous version
zdots schema rollback --to 2026-05-15 --confirm

# View migration history
zdots schema history
zdots schema history --json

# Validate current schema
zdots schema validate                     # check consistency
zdots schema validate --fix               # auto-fix issues if safe
```

#### Implementation Notes

1. **Storage:** Migrations in `db/migrations/` with version prefix
2. **Tracking:** `~/.zdots/schema-version.yaml` records applied migrations
3. **Idempotency:** Migrations must be idempotent (safe to apply multiple times)
4. **Validation:** Post-migration checks ensure success
5. **Rollback:** Optional; only if reversible

#### Benefits

- **Versioned:** Clear what version each machine is on
- **Auditable:** History of all schema/config changes
- **Reproducible:** Same migrations on all machines
- **Safe:** Validation, dry-run, rollback options

---

## Gap 7: Explicit Job Submission & Queue Management

### Problem

Jobs only enqueued as side effects. No way to submit jobs directly, monitor queue, or debug stuck jobs.

### Proposed Solution: Job Submission CLI

```bash
# Submit a job
zdots job enqueue embed --payload "$(cat lesson.txt)"
# Output: Job ID: abc123def456

# List jobs
zdots job list                          # all jobs
zdots job list --status pending         # pending jobs
zdots job list --status running         # currently running
zdots job list --type embed             # by type
zdots job list --last 10                # 10 most recent

# View job details
zdots job show abc123def456
zdots job show abc123def456 --json

# Watch a job
zdots job watch abc123def456             # stream status
zdots job wait abc123def456              # block until complete

# View job logs
zdots job logs abc123def456              # stdout/stderr from job
zdots job logs abc123def456 --tail 50    # last 50 lines

# Cancel a job
zdots job cancel abc123def456 --confirm

# Clear stale jobs
zdots job clear-stale --older-than 1h    # jobs stuck > 1 hour
zdots job clear-stale --all              # dangerous!

# Queue management
zdots job queue-depth                    # how many jobs pending
zdots job queue-depth --type embed       # by type
zdots job queue-health                   # queue health check
```

#### Design: Job Lifecycle

```
Job State Machine:
  pending → running → complete | failed
  running → timeout (after deadline)
  any → cancelled (manual)

Metadata:
  - ID (unique)
  - Type (embed, distill, docs_sync, transcription)
  - Payload (input data)
  - State (pending, running, complete, failed, cancelled)
  - Started (timestamp)
  - Completed (timestamp)
  - Result (output data, if applicable)
  - Error (if failed)
```

#### Implementation Notes

1. **Storage:** PostgreSQL `jobs` table
2. **Worker:** Claims one job at a time
3. **Status:** Queryable via CLI or API
4. **Observability:** Each job is a trace

---

## Gap 8: Scripting / Batch Language

### Problem

Multi-command logic currently in shell scripts (bash, zsh). Hard to test, port, maintain, audit.

### Proposed Solution: Zdots Scripting Language

```
# ~/.zdots/scripts/nightly-maintenance.zsh

#!/usr/bin/env zdots-script

# Zdots scripting language: bash-like syntax, type-safe, portable

# Variables
set -e                     # fail on error
script_name = "nightly_maintenance"
log_level = "info"

# Functions
function check_health() {
  result = $(zdots-ctl check --json)
  if result.status == "fail" {
    error "Platform check failed"
    return 1
  }
  return 0
}

# Main logic
info "Starting nightly maintenance"

if ! check_health {
  alert "Platform unhealthy; aborting maintenance"
  exit 1
}

info "Syncing history..."
zdots-ctx sync-history || {
  warn "History sync failed; continuing"
}

info "Reindexing embeddings..."
zdots-brain reindex-embeddings

info "Rotating credentials..."
zdots-ctx rotate-creds

info "Nightly maintenance complete"
```

#### CLI Interface

```bash
# Run a script
zdots script run nightly-maintenance
zdots script run nightly-maintenance --log-level debug

# Validate a script
zdots script validate nightly-maintenance
zdots script lint nightly-maintenance

# Test a script (dry-run)
zdots script test nightly-maintenance --dry-run

# Schedule a script
zdots script schedule nightly-maintenance --trigger "cron 0 2 * * *"

# List scripts
zdots script list

# View script
zdots script show nightly-maintenance --json
```

#### Benefits

- **Portable:** Runs on any machine with zdots
- **Typed:** Variables have types; better error messages
- **Testable:** `--dry-run` and `--test` modes
- **Auditable:** Execution logged and traced

---

## Gap 9: Environment Isolation (Testing, Multi-Setup)

### Problem

Single machine state. Hard to test destructive operations. Hard to set up multiple isolated environments (CI, staging, production).

### Proposed Solution: Environment Isolation

```bash
# Create isolated environment
zdots env new test-env                  # copy of current state
zdots env new staging --from prod       # clone from another env
zdots env list

# Activate environment
ZDOTS_ENV=test-env zdots-ctl check      # run in specific env
zdots env activate test-env             # set as default
zdots env active                        # show current

# Copy environment
zdots env copy prod staging             # clone prod → staging

# Delete environment
zdots env delete test-env --confirm
```

#### Design: Environment Structure

```
Each environment is a complete, isolated copy:
  ~/.zdots/environments/test-env/
    ├── config.yaml           (independent config)
    ├── postgres_data/        (isolated PostgreSQL)
    ├── redis_data/           (isolated Redis)
    ├── llama_state/          (isolated llama.cpp state)
    └── logs/                 (isolated logs)
```

---

## Gap 10: Capability Discovery & Introspection

### Problem

No programmatic way to query what zdots can do, what services are available, what commands exist. Agents must hardcode assumptions.

### Proposed Solution: Discovery & Introspection

```bash
# List all capabilities
zdots capability list

# Check if capability exists
zdots capability check "does-ai-inference"    # exit 0 if available
zdots capability check "has-pgvector"         # check embedding support

# Query capabilities
zdots capability query "service:llama"        # what can I do with llama?
zdots capability query --requires "python3"  # what needs python?

# List commands
zdots command list                    # all commands
zdots command list --domain ai        # in a domain
zdots command list --filter "sync"    # match pattern

# Get help
zdots help <command>                  # usage for command
zdots help <concept>                  # explanation of concept (e.g., "Workflow")
zdots help --all                      # full manual

# Agent capabilities
zdots agent list                      # available agents (Pi, Aider, Claude Code)
zdots agent capabilities pi-agent     # what can pi-agent do?
```

#### Implementation Notes

1. **Metadata:** Commands registered with metadata (name, args, help, domain)
2. **Discovery:** API to query metadata
3. **Capability:** Registered as "can do X" (computed from health checks)
4. **Schema:** All metadata validated against JSON Schema

---

## Summary: Rollout Priority

**Phase 1 (Foundational):**
1. Configuration System (Gap 1)
2. Schema Versioning (Gap 6)

**Phase 2 (Orchestration):**
3. Workflow System (Gap 2)
4. Job Submission (Gap 7)

**Phase 3 (Observability & Safety):**
5. Alert System (Gap 3)
6. Access Control (Gap 4)

**Phase 4 (Usability):**
7. Templates (Gap 5)
8. Scripting (Gap 8)
9. Environment Isolation (Gap 9)
10. Discovery (Gap 10)