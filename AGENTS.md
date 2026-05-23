# AGENTS.md — Core Context for AI Agents

Zdots is a modular, high-performance Zsh configuration ("Observable Control Plane").

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

| Need | Tool |
|---|---|
| Multi-file reasoning | Claude Code (`cl`) or `zaider` (Aider) |
| Interactive code edit | `zaider` — Aider wired to local llama.cpp |
| Low-priority / background edits | `laid` — `zaider` at nice +19, reduced threads |
| Scripted inference | `ai-query` |
| Context reduction | `rtk` |

## 4. Project Protocols

- **Tasks:** Use the `backlog` CLI. See [docs/backlog.md](docs/backlog.md).
- **Environment:** Use `ztask start <id>` when starting work to hydrate context.
- **Observability:** This is an observable session linked to the shell via `gemini-invoke`. Every tool call you make is tracked.
- **Standards:** Follow the [Zsh Quality Rubric](docs/zsh-quality-rubric.md).
- **Setup:** See [SETUP.md](SETUP.md) for new machine setup.
- **Testing:** See [docs/testing.md](docs/testing.md).

---

## 5. zdots Is Not Yours to Fix

zdots is the infrastructure. You are a tenant, not the maintenance crew.

**If zdots behaves unexpectedly — a tool errors, a service won't start, a command does something undocumented — your job is to file an issue and stop. Not to fix it.**

Unauthorized modifications to zdots break the environment for all agents and the operator. The system is designed and maintained by the operator. Like a good union job: don't touch the wiring unless it's your wiring.

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
| LGTM Stack | `local-ci` | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
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

**Endpoint:** `ZDOTS_AI_ENDPOINT` (default `http://127.0.0.1:8080`). Override in `.zdots.local` to point at a remote LAN machine.

**Aider context management** (7B model — be deliberate):
- `/add file.rb` — add only what you're editing
- `/drop file.rb` — free context when done
- `/clear` — wipe history between tasks
- `/tokens` — check budget before adding large files

## 9. PHI Operating Mode

This codebase operates near protected health information. The following rules are **non-negotiable** and enforced at the kernel/OS boundary — not just by convention.

**Hard rules:**
- `ZDOTS_AI_MODE=local` is the default. Never change it to `cloud` without an explicit security review for that machine.
- `ZDOTS_CAPTURE_ENABLED=0` until `ZDOTS_DB_ENCRYPTION_KEY` is provisioned in Keychain and DB encryption is verified.
- All AI calls pass through `lib/phi_scrubber.bash` before sending. The scrubber is the **first** gate, not the last — do not send raw patient records.
- `lib/ai_boundary.bash` enforces locality: exits 2 if `ZDOTS_AI_MODE=none`, exits 1 if endpoint is not loopback/RFC-1918 in local mode.

**Audit trail:**
- Every PHI-adjacent operation emits to macOS Unified Logging: `subsystem=com.zdots category=phi-boundary`
- Query: `log show --predicate 'subsystem == "com.zdots"' --last 1h`
- This survives OTel being down and cannot be cleared without root.

**Verify posture:** `zdots-ctl check` (hard-fails on FileVault/SIP; checks AI mode, capture, history-redact, llama-server bind, model provenance).

Full policy: `backlog/docs/doc-002 - PHI-Safety-Policy.md`
