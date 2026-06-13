# AGENTS.md — Core Context for AI Agents

Zdots is a modular, high-performance Zsh configuration ("Observable Control Plane").

---

## The Schrute Test

> "Whenever I'm about to do something, I think: would an idiot do that?
> And if they would, I do not do that thing." — Dwight Schrute

Apply before every action. Covers:
- Modifying zdots without operator coordination
- Proceeding without verification
- Assuming confidence equals correctness
- Any action whose blast radius exceeds the task scope

If the answer is yes — stop. File a `zdots-issue`. Ask. Do not proceed.

---

## Kevin's Law

> "Why waste time, say lot word when few word do trick?" — Kevin Malone

Few word do trick. Always.
- No filler. No hedging. No pleasantries.
- Technical terms exact. Code first. Prose only when code not enough.
- Output serves the reader, not the writer.

This applies to every response, comment, commit message, and issue filed.
The Caveman voice in `zdots-ask` is Kevin's Law applied to local AI.

---

## 1. Orientation

Run these to understand the current state of the machine:
```bash
zdots-ctl status    # aggregate service status
capabilities --json  # environment contract validation
agent-guide          # detailed usage guide for all services
```

## 2. Token Optimization (RTK)

**Rule:** Always proxy high-output commands through `rtk`.

| Workflow | Patterns |
|---|---|
| **Git** | `rtk git status`, `rtk git diff`, `rtk git log` |
| **Infra** | `rtk docker logs`, `rtk fly logs` |
| **Analysis** | `rtk tokei`, `rtk summary <cmd>` |

## 3. Tool Selection

### Rule zero: zdots first, always

**Before reaching for any external or generic tool, check whether zdots already provides it.**
`~/.config/zsh/bin` is always on `PATH` regardless of working directory.
In a project directory, `./bin` is also on `PATH` — commands run without the `./bin/` prefix.

```bash
zdots-ctx hydrate tooling-catalog   # compact command index + task-to-tool scenarios
zdots-ctx query tooling:<name>      # full --help for a specific command
zdots-ctx query --semantic "start a service"  # natural-language lookup
```

The catalog is rebuilt whenever `bin/` changes and refreshed every 7 days. If a command appears in the catalog, it works as-is — no path prefix, no install step.

**If zdots doesn't have it:** file a request with `zdots-issue --type request "I need X for task Y"` and work around it at the task level. Do not reach for an external tool and do not patch zdots infrastructure yourself.

Full tool reference with usage examples: [docs/tooling.md](docs/tooling.md)

### Colima / Docker — always use the interface, never probe directly

```bash
colima-status --json       # authoritative JSON: healthy, socket path, docker_host
colima-status socket       # just the socket path — DOCKER_HOST=$(colima-status socket)
colima-status health       # exit 0 = up; exit 1 = down
```

**Never hardcode the socket path.** The socket moved from `~/.colima/` to `~/.config/colima/` in recent colima versions. Scripts that hardcode the old path silently miss the socket and burn tokens looping on false negatives. `colima-status` tries both locations and warns loudly when it finds the legacy one.

**By task:**

| Need | Tool |
|---|---|
| Multi-file reasoning | Claude Code (`cl`) or `zaider` (Aider wired to local llama.cpp) |
| Interactive code edit | `zaider` |
| Low-priority / background edits | `laid` — `zaider` at nice +19, reduced threads |
| Scripted inference | `ai-query` |
| Context reduction | `rtk` |
| Full codebase context | `repomix --output context.xml` |
| Explore command analytics (SQLite) | `litecli ~/.local/state/zdots/history.sqlite3` |
| Explore knowledge base (PostgreSQL) | `pgcli -U zdots_ro my` |
| Pivot/analyze command_runs | `visidata ~/.local/state/zdots/history.sqlite3` |
| Script SQLite queries | `sqlite-utils query <db> "SELECT ..."` |
| Inspect Redis analytics buffer | `redis-cli KEYS 'zdots:cmds:*'` |
| Rotate a service log (compress + truncate in-place) | `log-rotate <service>` |
| Colima/Docker status (always) | `colima-status --json` |
| Docker socket path | `colima-status socket` |
| Verify AI stays on loopback | `sudo bandwhich` |
| Run tests once | `bats tests/` |
| Run tests on save | `watchexec -e zsh,bash,bats -- bats tests/` |
| Check YAML validity | `yamllint etc/phi-patterns.yaml` |
| Secret scan before commit | `bin/secret-scan` (or `gitleaks detect`) |

## 4. Project Protocols

- **Tasks:** Use the `backlog` CLI. See [docs/backlog.md](docs/backlog.md).
- **Environment:** Use `ztask start <id>` when starting work to hydrate context.
- **Knowledge Base:** Use `zdots-ctx query`, `zdots-ctx query --semantic`, and `zdots-ctx hydrate` before claiming missing context. See [docs/wiki/AI-and-Knowledge-Layer.md](docs/wiki/AI-and-Knowledge-Layer.md).
- **Observability:** This is an observable session linked to the shell via `gemini-invoke`. Every tool call you make is tracked.
- **Standards:** Follow the [Zsh Quality Rubric](docs/zsh-quality-rubric.md).
- **Setup:** See [SETUP.md](SETUP.md) for new machine setup.
- **Testing:** See [docs/testing.md](docs/testing.md).

---

## 5. zdots Is Not Yours to Fix

zdots is the infrastructure. You are a tenant, not the maintenance crew.

**If zdots behaves unexpectedly — a tool errors, a service won't start, a command does something undocumented — your job is to file an issue and stop. Not to fix it.**

This is not primarily about authorization. It is about **coordination**.

Every function in `lib/`, every script in `bin/`, every contract in `conf.d/` has callers you cannot see from your current task. If you change the behavior of `zdots_ai_gate` to unblock yourself, you do not know what the three other scripts that call it are expecting. If you rename a flag in `zdots-ctx`, you do not know which agent sessions, cron jobs, or shell aliases depend on the old flag. Your fix may be locally correct and still cause silent failures downstream — with no notification to the operator, no signal to other agents, and no way to recover except by debugging a system whose state no one fully understands anymore.

The operator coordinates changes to zdots. That coordination is the entire point. Like a good union job: don't touch the wiring unless it's your wiring — not because you're not trusted, but because the electrician is the only one who knows what else is on that circuit.

```bash
zdots-issue "Short description of the problem"
zdots-issue --type question "Does zdots support X?"
zdots-issue --type request  "I need zdots to do Y to complete task Z"
zdots-issue --high          "This is blocking my current task"
```

`zdots-issue` creates a tracked backlog task with your trace ID attached. The operator reviews and resolves. You wait, work around it at the task level, or stop.

**What counts as a zdots issue (file it, don't fix it):**
- A `bin/` script exits with an unexpected code or error message
- A service (`llama-ctl`, `otel-collector`, `zdots-ctx`) behaves contrary to its `--help`
- A lib function (`zdots_ai_gate`, `phi_scrub`, etc.) is missing or broken
- A migration fails or the schema doesn't match what docs describe
- You need a capability zdots doesn't have

**What is NOT a zdots issue (your job):**
- Bugs in code you were asked to write
- Test failures in tests for your feature
- Configuration in `.zdots.local` or `.zdots.env` for your specific task
- Choosing which zdots tool to use for a given problem

---

## 6. Reference

| Service | Manager | Doc |
|---|---|---|
| AI (llama.cpp) | `llama-ctl` | [docs/llama-cpp.md](docs/llama-cpp.md) |
| Transcription | `whisper-ctl` | [README.md](README.md) |
| OTel | `otel-collector` | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| Observability | `openobserve-ctl` (`zsvc o2`) | [docs/openobserve.md](docs/openobserve.md) |
| LGTM Stack (migrating → OpenObserve, Z-134) | `local-ci` | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| Orchestrator | `zdots-ctl` | [README.md](README.md) |

## 7. Database

| Attribute | Value |
|---|---|
| Database | `my` (PostgreSQL) — do **not** use `zdots` (unrelated legacy schema) |
| Schema owner | `zdots-brain` via Sequel migrations in `db/migrations/` |
| Migration user | OS user (superuser) via `ZDOTS_MIGRATION_URL` |
| App user | `zdots_rw` — write access via `zdots-ctx` / `context-engine` only |
| Read-only | `zdots_ro` — SELECT only, safe for ad-hoc queries |
| App connection | `ZDOTS_DATABASE_URL=postgresql://zdots_rw@/my` |
| Migration command | `zdots-ctx migrate` |

Safe exploration: `psql -U zdots_ro my`

Do **not** set `DATABASE_URL` — it has no owner in this stack and causes confusion. Use `ZDOTS_DATABASE_URL` for app connections and `ZDOTS_MIGRATION_URL` for migrations.

## 8. AI Stack

All AI runs locally by default (`ZDOTS_AI_MODE=local`). No cloud API keys are configured until explicitly added to `.zdots.secrets`.

| Tool | Purpose | Invocation |
|---|---|---|
| `ai-query` | Scripted / piped inference | `ai-query "prompt"` or `cmd \| ai-query "task"` |
| `zdots-ask` | Domain-aware prompt router (local LLM) | `zdots-ask "prompt"` or `zdots-ask --domain ruby "..."` |
| `zdots-quiz` | 14-case capability probe for local model | `zdots-quiz --quick` (3 cases) or `zdots-quiz` (full) |
| `zaider` | Aider wired to local llama.cpp | `zaider` (from any repo directory) |
| `laid` | Low-priority Aider | `laid` (nice +19, reduced threads) |
| `zdots-ctx query` | Search local knowledge base | `zdots-ctx query <term>` |
| `zdots-ctx hydrate` | Context blob for AI tasks | `zdots-ctx hydrate [tag]` |

**Endpoint:** `ZDOTS_AI_ENDPOINT` (default `http://127.0.0.1:11500`). Override in `.zdots.local` to point at a remote LAN machine.

**Aider context management** (7B model — be deliberate):
- `/add file.rb` — add only what you're editing
- `/drop file.rb` — free context when done
- `/clear` — wipe history between tasks
- `/tokens` — check budget before adding large files

## 9. Vocabulary & Communication Standards

Zdots has formal vocabulary (CONTEXT.md, GLOSSARY.md, ONTOLOGY.md). Use exact terms consistently in code, commits, PRs, and conversations.

**Core Terms (always use exact form):**

| Term | Do NOT Use | Reason |
|---|---|---|
| **Platform Service** | service, microservice, daemon | Specific lifecycle model (start/stop/restart with health probes) |
| **Seam** | boundary, interface, API, facade | Specific meaning: place where behavior changes without editing in place |
| **Knowledge Layer** | Intelligence Suite, ML layer, AI layer | Exact name; not interchangeable |
| **Session Residue** | capture, transcript, session log, record | Specific meaning: raw distillation with intent/result/summary |
| **Lesson** | note, doc, article, knowledge unit | Specific meaning: curated, atomic, tagged |
| **Methodology** | best practice, pattern, principle | Specific meaning: synthesized from multiple lessons |
| **Message Hygiene Pipeline** | sanitizer, scrubber pipeline, cleaning | Specific stages: normalize, then PHI scrub (order matters) |
| **PHI Scrubber** | PHI scrubbing, redactor, scrubber | Noun: the component; not the verb "scrubbing" |
| **Virtuous Loop** | feedback loop, cycle, learning loop | Specific pattern: Work → Capture → Curate → Infer → Repeat |
| **Workflow** | pipeline, job, script, task | Declarative, composable, observable (not imperative shell script) |
| **Alert** | alert rule, notification, trigger | Specific: condition-based, with actions and thresholds |
| **Actor** | user, agent, principal, client | In access control context; includes humans, agents, services |
| **Access Control** | permissions, ACL, auth, RBAC | Specific system: roles + actor + allow/deny rules |
| **Capability** | feature, service, function, operation | Discoverable, attestable facility (does-ai-inference) |

**Why Vocabulary Matters:**

1. **Precision:** "Seam" means a specific pattern; "boundary" is vague. Using exact terms prevents miscommunication.
2. **Searchability:** When agents search code for "Seam", they find the pattern. Searching "boundary" finds noise.
3. **Load-bearing decisions:** Terms like "Session Residue" vs. "transcript" encode design choices (why it's not just logs).
4. **Consistency:** Exact vocabulary across code, docs, and PRs makes the system understandable.

**In Commit Messages:**

Use present-tense verb + domain noun. Example:
```
fix(phi-scrubber): consolidate into canonical Go binary (ADR-0002)

PHI Scrubber had dual implementations (bash, Ruby) with contract-test-only
enforcement. Risk: silent divergence on suppress-flagged patterns.

Solution: Canonical Go binary with thin adapters. Benefits: single source of
truth, RE2 engine matches collector, eliminates 3-engine drift.

Related: ADR-0002, DSL Matrix (Gap 1)
```

**In Issues & PRs:**

```
Title: PHI Scrubber unification — move redaction to Go binary

Body:
## Problem
Dual-impl sync burden; silent divergence risk.

## Solution
Canonical Go binary (cmd/zdots-phi-scrub/), bash/Ruby adapters call it.

## Benefits
Single source, contract-test clarity, RE2 parity.

## Related
ADR-0002, Service Registry deepening (blocks on this)
```

**In Documentation:**

- Reference CONTEXT.md when introducing a concept
- Use GLOSSARY.md definitions
- Use ONTOLOGY.md to show relationships

**In Code Comments:**

Only comment WHY, not WHAT. Use vocabulary consistently:

```bash
# Bad: "This function scrubs PHI from input"
# (too obvious; uses "scrub" as verb)

# Good: "Apply the PHI Scrubber before inference"
# (references component by name; reader can look up semantics in GLOSSARY)
```

---

## 10. PHI Operating Mode

This codebase operates near protected health information. The following rules are **non-negotiable** and enforced at the kernel/OS boundary — not just by convention.

**Hard rules:**
- `ZDOTS_AI_MODE=local` is the default. Never change it to `cloud` without an explicit security review for that machine.
- `ZDOTS_CAPTURE_ENABLED=0` until `ZDOTS_DB_ENCRYPTION_KEY` is provisioned in Keychain and DB encryption is verified.
- `ZDOTS_CMD_ANALYTICS=0` on work machines — `.zdots.work` enforces this. Never enable it without checking `ZDOTS_CONTEXT`.
- All AI calls pass through `lib/phi_scrubber.bash` before sending. The scrubber is the **first** gate, not the last — do not send raw patient records.
- All shell commands pass through `_zca_redact` (suppress + scrub) before reaching the analytics store. Suppress-flagged commands (connection strings) are dropped entirely — not redacted. This is enforced in `conf.d/56-cmd-analytics.zsh`.
- `lib/ai_boundary.bash` enforces locality: exits 2 if `ZDOTS_AI_MODE=none`, exits 1 if endpoint is not loopback/RFC-1918 in local mode.
- To add a PHI or credential pattern, edit `etc/phi-patterns.yaml` **only**. No other file may define patterns. The registry auto-compiles at shell startup and applies to all layers.

**Audit trail:**
- Every PHI-adjacent operation emits to macOS Unified Logging: `subsystem=com.zdots category=phi-boundary`
- Query: `log show --predicate 'subsystem == "com.zdots"' --last 1h`
- This survives OTel being down and cannot be cleared without root.

**Verify posture:** `zdots-ctl check` (hard-fails on FileVault/SIP; checks AI mode, capture, history-redact, llama-server bind, model provenance).

Full policy: `backlog/docs/doc-002 - PHI-Safety-Policy.md`
