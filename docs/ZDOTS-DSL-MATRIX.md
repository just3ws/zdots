# Zdots DSL Matrix — Commands, Patterns, and Speculative Gaps

A structured map of the emergent domain-specific language in zdots: what commands exist, what patterns they follow, what's missing.

---

## I. Command Families & Domains

| Family | Primary Commands | Domain | Responsibility |
|---|---|---|---|
| **Service Control** | `zsvc`, individual `*-ctl` | Platform Service | Lifecycle (start/stop/restart), health, logs |
| **Platform Orchestration** | `zdots-ctl` | Platform | Aggregate status, coordination, diagnostics |
| **Knowledge Layer** | `zdots-ctx`, `zdots-brain` | Persistence | Query, capture, curation, schema migration |
| **AI Inference** | `ai-query`, `zdots-ask`, `zaider` | AI invocation | Raw prompting, domain routing, code editing |
| **Observability** | `zdots-o2-query` | Tracing/metrics | Query traces, logs, spans |
| **AI Deliberation** | `zsynod` | Multi-agent | Council, quorum, persistent ledger |
| **Configuration** | (none) | Config | **[GAP]** No unified config read/write/validate |
| **Scripting/Workflows** | (none) | Automation | **[GAP]** No task/pipeline/DAG language |

---

## II. Verb Inventory — What Actions Exist?

### Universal Verbs (appear in 3+ families)

| Verb | Contexts | Semantics |
|---|---|---|
| **start** | zsvc, zdots-ctl | Begin a process/system |
| **stop** | zsvc, zdots-ctl | End a process/system |
| **status** | zsvc, zdots-ctl, zdots-ctx | Query current state |
| **restart** | zsvc, zdots-ctl | Stop then start |
| **reset** | zdots-ctl | Hard restart (wipe + reinit) |
| **check** | zdots-ctl | Deep health diagnostic |
| **logs** | zsvc | Tail service log |
| **query** | zdots-ctx, zdots-o2-query | Search/lookup in persistence layer |
| **hydrate** | zdots-ctx | Load context blob for AI |

### Service-Specific Verbs

| Verb | Command | Semantics |
|---|---|---|
| **diag** | zsvc | Full diagnostic (status + health + logs + metadata) |
| **health** | zsvc | Probe liveness |
| **capture** | zdots-ctx | Distill session into residue |
| **migrate** | zdots-ctx | Schema versioning |
| **sync-history** | zdots-ctx | Drain Redis → SQLite → PostgreSQL |
| **rotate-creds** | zdots-ctx | Refresh database passwords |
| **claim-next-job** | Worker (internal) | Worker claim from queue |
| **convene** | zsynod | Start a deliberation session |
| **ratify** | zsynod | Consensus on a decision |

### Present but Underspecified Verbs

| Verb | Commands | Issue |
|---|---|---|
| **help** | Most (via `--help`, `/help` skill) | No unified help format/discovery |
| **validate** | `yamllint` (external) | No standard validation across config types |
| **test** | `bats`, `ruby-audit` (external) | No unified test runner |
| **init** | `zdots-ctl install` | Inconsistent with `--init` pattern elsewhere |
| **clear** | `zdots-ctx clear-stale-jobs` | Semantic overload (wipe? reset? drain?) |

---

## III. Noun Inventory — What Objects Exist?

### Platform Concepts (in CONTEXT.md)

| Noun | Singular | Plural | Accessor | Example Use |
|---|---|---|---|---|
| **Service** | service | services | `zsvc resolve <name>` | `zsvc status llama` |
| **Platform Service** | — | — | typed by `type:` in registry | Core/Cache/Hosted classification |
| **Job** | job | jobs | queue in PostgreSQL | `zdots-ctx clear-stale-jobs` |
| **Lesson** | lesson | lessons | `zdots-ctx query lessons:*` | Knowledge unit |
| **Methodology** | methodology | methodologies | `zdots-ctx query methodologies:*` | Synthesized principle |
| **Session Residue** | residue | residue (uncountable?) | by `trace_id` | Raw distillation |
| **Trace** | trace | traces | `zdots-o2-query trace <id>` | Execution record |
| **Pattern** | pattern | patterns | registry: `etc/phi-patterns.yaml` | PHI/credential match rule |
| **Command** | command | commands | `sqlite3 history.sqlite3` | Audit record |

### Implicit Nouns (Not Yet Named as First-Class Objects)

| Concept | Current Representation | Ideal Noun | Gap |
|---|---|---|---|
| Health metric | Property of service status | **health**? | No noun for "check result" |
| Config document | File on disk | **config**, **settings**? | No standard config object model |
| Workflow/DAG | Implicit in shell scripts | **workflow**, **pipeline**? | **[GAP]** No workflow DSL |
| Alert rule | Implicit in monitoring | **alert**, **rule**? | **[GAP]** No alert system |
| User/agent | Implicit in audit | **actor**, **principal**? | **[GAP]** No access control model |
| Capability | Advertised in `capabilities --json` | **capability**? | **[GAP]** No discovery/delegation language |

---

## IV. Modifier/Option Inventory — Consistency Gaps

### Flags That Appear Widely

| Flag | Commands | Behavior |
|---|---|---|
| **--json** | zsvc, zdots-ctl, zdots-ctx, zdots-o2-query | Structured output |
| **--help** | Most | Usage |
| **--quiet** | zdots-ctl check | Suppress non-critical output |
| **--no-runtime** | zdots-ctl | Skip external service checks |

### Flags That Should Be Universal But Aren't

| Intended Flag | Current Workaround | Affected Commands |
|---|---|---|
| **--dry-run** | (none) | zdots-ctx migrate, zdots-ctl up/down (should allow preview) |
| **--watch** | (none) | zsvc status, zdots-ctl status (should stream updates) |
| **--format** | --json only | Should support: json, yaml, table, csv |
| **--filter** | Implicit in service name | Should be explicit for all list commands |
| **--timeout** | Hard-coded | Should be configurable for network calls |

---

## V. Argument Patterns — Semantic Consistency

### Pattern 1: Positional Service Name
```
zsvc   start <svc>          # service by name (alias or canonical)
zsvc   start llama          # resolves via registry

zdots-ctl up                # no service arg; implies all
zdots-ctl check             # no service arg; implies all
```

**Gap:** No `zdots-ctl start <svc>` equivalent. Service control routed entirely through `zsvc`.

### Pattern 2: Query/Search
```
zdots-ctx query <term>                      # substring or tag search
zdots-ctx query --semantic "find lessons"   # AI-powered search
zdots-o2-query trace <id>                   # by ID
zdots-o2-query errors | failures | trace    # by predefined type
```

**Gap:** Inconsistent — some commands are predicates (`| errors`), others are flags (`--semantic`).

### Pattern 3: Hydration/Context Loading
```
zdots-ctx hydrate [tag]          # Load knowledge blob for AI
zdots-ctx hydrate tooling-catalog # By explicit tag
```

**Gap:** Only one source (knowledge base). No equivalent for config, service metadata, or schema.

### Pattern 4: Async Job Submission
```
# Implicit: zdots-ctx capture enqueues jobs
# No explicit job-submission command
```

**Gap:** Jobs are only submitted via side effects. No `zdots-ctx enqueue --type embed --payload "..."`.

---

## VI. Exit Codes — Semantic Inconsistency

| Command | Exit 0 | Exit 1 | Exit 2 | Convention |
|---|---|---|---|---|
| `zsvc status` | OK | Any fail | — | Binary |
| `zdots-ctl check` | All pass | Warn | Fail | Ternary (should be 0/1?) |
| `zdots-phi-scrub` | Success | Suppress match | Usage error | (Ternary on semantics) |
| `phi_should_suppress` | Match | No match | — | Inverted binary (0=true) |

**Gap:** No standard exit-code semantics across commands. Callers must know each command's convention.

---

## VII. Speculative Gaps — What the DSL Needs

### Gap 1: Unified Config Language
**Missing:** A single model for authoring and querying config.

**Current state:** 
- `.zdots.local` (bash)
- `.zdots.env` (bash)
- `.claude/settings.json` (JSON)
- `etc/phi-patterns.yaml` (YAML)
- Plist files for launchd
- PostgreSQL schema (migrations)

**Speculative solution:**
```
zdots config get AI_MODE                    # Read a setting
zdots config set AI_MODE local              # Write a setting
zdots config validate --schema schema.yaml  # Validate all config
zdots config apply --from template.yaml     # Apply a template
```

**Benefits:** Discoverable settings, validation, templating, audit trail.

---

### Gap 2: Workflow/Pipeline DSL
**Missing:** A way to compose commands into repeatable workflows.

**Current state:** Shell scripts or manual invocation sequences.

**Speculative solution:**
```yaml
# .zdots/workflows/daily-sync.yaml
name: daily_sync
trigger: cron "0 9 * * *"
steps:
  - name: database_check
    command: zdots-ctx status
    timeout: 30s
  - name: sync_knowledge
    command: zdots-ctx sync-history
    on_failure: continue
  - name: reindex_embeddings
    command: zdots-brain reindex-embeddings
    depends_on: sync_knowledge
  - name: notify
    command: zsynod request "Daily sync complete"
    depends_on: reindex_embeddings
```

**Invocation:**
```
zdots workflow run daily-sync              # Run by name
zdots workflow list                        # List all
zdots workflow status daily-sync           # Check last run
```

**Benefits:** Declarative, reusable, observable, compatible with the Virtuous Loop.

---

### Gap 3: Alert/Health Thresholds
**Missing:** A declarative way to define alerts and escalation.

**Current state:** Manual polling, no thresholds, no escalation policy.

**Speculative solution:**
```yaml
# .zdots/alerts/llama-health.yaml
alert: llama_down
condition: "service.health != healthy"
threshold: 1m                              # Alert if unhealthy for > 1min
severity: high
actions:
  - notify: slack "#ops"
  - action: restart llama                  # Auto-remediate
  - action: convene zsynod "llama failure" # Ask council
```

**Invocation:**
```
zdots alert list                          # List active alerts
zdots alert silence llama_down --for 1h   # Temporary silence
```

**Benefits:** Observable failure modes, auto-remediation options, human-in-the-loop.

---

### Gap 4: Access Control / Multi-Actor Model
**Missing:** A way to define roles, permissions, audit trails for multi-user or multi-agent access.

**Current state:** All-or-nothing. Agents have full access or none.

**Speculative solution:**
```yaml
# .zdots/access-control/agents.yaml
actors:
  - name: pi-agent
    role: researcher
    permissions:
      - "zdots-ctx query"
      - "zdots-ask --domain ruby"
      - "zdots-ctx capture"           # Can learn
      - deny: "zdots-ctx migrate"     # Cannot alter schema
  - name: deploy-agent
    role: deployer
    permissions:
      - "zsvc *"                      # Full service control
      - "zdots-ctl *"                 # Full platform control
      - deny: "zdots-ctx query"       # Cannot read knowledge
```

**Invocation:**
```
zdots actor add pi-agent                  # Enroll new actor
zdots actor check permission pi-agent "zdots-ctx query"
zdots audit --actor pi-agent --last 1h    # Audit trail
```

**Benefits:** Multi-agent safety, compliance, audit trail.

---

### Gap 5: Template/Blueprint System
**Missing:** A way to compose re-usable service definitions, workflows, configs.

**Current state:** Copy-paste, manual edits.

**Speculative solution:**
```
zdots template list                       # List available templates
zdots template new llama-service          # Initialize from template
zdots template apply template.yaml        # Apply to existing setup
zdots template export > backup.yaml       # Export current state as template
```

**Benefits:** Reproducibility, onboarding, disaster recovery.

---

### Gap 6: Schema Versioning / Data Migrations
**Missing:** A unified DSL for versioning configs and data schemas.

**Current state:** 
- Migrations via `zdots-ctx migrate` (database only)
- `.zdots.env` versioning? (implicit)
- Plist versioning? (implicit)

**Speculative solution:**
```yaml
# .zdots/schema-version.yaml
current: 2026-06-12
changes:
  - version: 2026-06-01
    description: "Add vectorstore schema"
    commands:
      - zdots-ctx migrate --to 20260601
      - zdots-brain reindex-embeddings
  - version: 2026-05-15
    description: "Rotate database credentials"
    commands:
      - zdots-ctx rotate-creds
```

**Invocation:**
```
zdots schema status                       # Current version
zdots schema upgrade                      # Run all pending migrations
zdots schema rollback --to 2026-05-15     # Downgrade (if reversible)
```

**Benefits:** Reproducible deployments, rollback capability, version tracking.

---

### Gap 7: Explicit Task/Job Submission
**Missing:** A way to enqueue jobs with structured payloads.

**Current state:** Jobs only via side effects (e.g., `zdots-ctx capture` implicitly enqueues `distill`).

**Speculative solution:**
```
zdots job enqueue embed --payload "$(cat transcript.txt)"
zdots job enqueue distill --from-session-residue abc123
zdots job list --status pending                         # Queue depth
zdots job watch abc123                                  # Stream progress
```

**Benefits:** Explicit control, debugging, monitoring.

---

### Gap 8: Scripting/Batch Language
**Missing:** A way to define multi-command sequences with variables, conditionals, error handling.

**Current state:** Shell scripts (bash, zsh). Hard to port, hard to audit, hard to test.

**Speculative solution:**
```
# .zdots/scripts/health-check.zdots
define health_check():
  status = zsvc status --json
  if status.llama.healthy:
    print "AI ready"
  else:
    error "AI unhealthy"
    zdots alert fire llama_unhealthy
    exit 1

when triggered by: cron "*/5 * * * *"
do: health_check()
```

**Invocation:**
```
zdots script run health-check              # Execute
zdots script test health-check             # Dry-run
zdots script schedule health-check --every 5m
```

**Benefits:** Portable, testable, auditable, typed.

---

### Gap 9: Namespace/Environment Isolation
**Missing:** A way to run parallel or isolated zdots environments (e.g., for testing).

**Current state:** Single machine state. Hard to test destructive operations.

**Speculative solution:**
```
zdots env new test-env                    # Create isolated copy
zdots env activate test-env                # Switch to it
zdots env list                             # Show available
zdots env copy prod-env -> staging-env    # Clone
zdots env delete test-env                  # Clean up
```

**Invocation:**
```
ZDOTS_ENV=test-env zsvc start llama       # Run in specific env
```

**Benefits:** Safe testing, CI/CD parity, disaster recovery.

---

### Gap 10: Capability Discovery / Introspection
**Missing:** A structured way to query what zdots can do, what agents are available, what commands exist.

**Current state:** `capabilities --json` (hidden), `--help` (inconsistent), docs (scattered).

**Speculative solution:**
```
zdots capability list                     # All available operations
zdots capability query "service:llama"    # What can I do with llama?
zdots capability check "does-ai-inference"
zdots command list --domain knowledge     # Commands in a domain
zdots agent list                          # Available agents (Pi, Aider, Claude Code)
```

**Benefits:** Programmatic introspection, auto-completion, permission enforcement.

---

## VIII. Matrix Summary — Command Coverage

| Concept | Explicit Verb? | Explicit Noun? | First-Class Object? | Observability |
|---|---|---|---|---|
| Service lifecycle | ✅ start/stop/restart | ✅ service | ✅ registry | ✅ status, logs |
| Health | ⚠️ implicit in `status` | ❌ "health" unchosen | ❌ property only | ✅ zsvc health |
| Knowledge | ✅ query/hydrate/capture | ✅ lesson/methodology/residue | ✅ PostgreSQL | ✅ zdots-ctx status |
| AI inference | ✅ (ai-query, zdots-ask) | ❌ "inference"? | ❌ implicit | ⚠️ OTEL only |
| Jobs | ⚠️ implicit (enqueue via capture) | ✅ job | ✅ PostgreSQL | ⚠️ via zdots-ctx |
| Config | ❌ no verb | ❌ no noun | ❌ scattered files | ❌ none |
| Workflows | ❌ no verb | ❌ no noun | ❌ shell scripts | ❌ none |
| Alerts | ❌ no verb | ❌ no noun | ❌ none | ❌ none |
| Access control | ❌ no verb | ❌ no noun | ❌ none | ❌ none |
| Scripting | ❌ no DSL | ❌ no noun | ❌ shell only | ❌ none |

---

## Conclusion: The Emerging Zdots DSL

**Strengths:**
- Clear service-lifecycle verbs (start/stop/restart)
- Emergent domain concepts (Lesson, Methodology, Session Residue)
- Knowledge layer structured and observable
- Multi-AI support (Pi, Aider, Claude Code, local)

**Weaknesses:**
- No unified config model
- No workflow/pipeline DSL
- No explicit task submission
- Inconsistent flags and exit codes
- No access control / multi-actor model
- No alert system
- No namespace isolation for testing

**Recommended Priority for Vocabulary Building:**

1. **Immediate (high ROI, low lift):**
   - Unify exit codes across commands (0/1/2)
   - Add --dry-run, --watch, --format to all list/status commands
   - Define explicit nouns: health, config, capability

2. **Short-term (enables others):**
   - Config DSL (unifies .zdots.local, .zdots.env, .claude/settings.json)
   - Workflow DSL (declarative job submission, observable runs)
   - Capability discovery (introspection for agents)

3. **Medium-term (completeness):**
   - Alert/threshold system
   - Access control model
   - Scripting/batch language
   - Schema versioning DSL

4. **Speculative (future):**
   - Namespace isolation
   - Multi-environment templating
   - Agent delegation/trust model
