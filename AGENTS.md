---
name: zdots-core-instructions
scope: zdots repository
audience: all coding agents
canonical: true
---

# AGENTS.md — Core Context for AI Agents

Zdots is a modular, high-performance Zsh configuration ("Observable Control Plane").

<!-- CURRENT FOCUS — 2026-10-31
     Exact task status: Git + Backlog. Session details and archive provenance:
     ~/.config/adots/handoffs/2026-10-31.md (local-only). Update before close.

  System map: docs/platform-map.md. Canonical identity maps are corrected and
  pushed in zdots, adots, my, vdots, and the public portfolio. Retired provider
  state is archived on /Volumes/Dock_1TB with provenance. Historical co-author
  attribution rewrite is deferred per operator; do not rewrite Git history now.

  Identity follow-up: portfolio alias and obsolete employer-policy cleanup are
  pushed at a5504d1a; Phalanx game alias map is pushed at 24ca26fb. Portfolio
  deployment passed. Phalanx tests, security checks, and build passed, but
  production release creation failed at the Fly.io provider gate; no retry was
  attempted. Its staged changes remain preserved. The UGLST GeoSrv
  mdh@just3ws.com alias remains unconfirmed; do not map it without operator
  confirmation. Do not alter time-bounded historical career records as part of
  the identity cleanup.

  Preserved branch candidates need operator disposition: portfolio
  `consultancy` is 35 commits ahead / 1,348 behind `origin/master` (45 changed
  files, latest commit May 5); Phalanx `feat/distributed-ledger` has 10 unique
  commits, is 1,404 behind `origin/main`, and has three staged license edits.
  Phalanx `godot/v2-client-parity` is six commits ahead of its remote. Do not
  delete or publish these without review.

  The retired experiment has no current-tree references; Git history and its
  checksummed local archive remain provenance. No force-pushes were made.

  Current CI/dependency evidence (2026-10-31): zdots Check and Secret Scan
  passed on 7b76072f. Dependabot has zero open alerts and zero open PRs (29
  closed alerts); no dependency changes were made in this review. media-pipeline
  is pushed at ec1dc67 and CI run 41254389048 passed; six generated
  graphify-out files remain locally modified and untouched.

  Phalanx game main still has a staged Claude/Codex/Gemini instruction cleanup;
  preserve it. Active docs and code still reference Claude Code and the
  Anthropic API. Treat client/config removal separately from the Anthropic
  product provider; do not remove a runtime provider without a scoped review.
  Phalanx distributed-ledger still has three staged license edits and 1,404
  commits of divergence; portfolio consultancy remains 35 ahead / 1,348 behind.
  Keep both and the six-commit Godot branch pending operator disposition.

  The durable bus and manual CLI remain. Optional busdriver is parked. Existing
  localhost routes are indexed in docs/local-url-routing.md; do not add hosts
  without a clear workflow. nginx validation/reload requires operator sudo.

  Video recording/editing are critical. Preserve media sources and maintain
  about 45 GiB internal free space. Colima is installed for on-demand use only.
  Keep local adots git/npm config edits and my's untracked databases/private
  vault untouched. Recent cleanup commits: f8078deb (retire stale provider
  guidance), d8e3d8a0 (close stale backlog and fix patch-export path),
  0663c1fb (map recording and media workflow), 794fdd6 (remove retired home
  instructions). Earlier milestones are in Git history and the handoff.
-->



---

## Operating Discipline

- **Check before changing.** Identify current state, callers, ownership, and
  recovery path before touching a shared seam. Prefer a dry run and exact-path
  review. Never stage a diff you have not inspected.
- **Smallest safe change.** Follow existing structure; prefer deletion and
  standard-library solutions. Avoid speculative configuration or abstractions.
- **Slow down at irreversible boundaries.** PHI, credentials, public history,
  shared contracts, and force-pushes require a verified recovery path and
  explicit operator direction.
- **Prove important claims.** Use a check that can fail before a fix, then
  confirm it passes after. Do not describe an unrun check as verified.
- **Stop when the work is complete.** Review the diff, record provenance, and
  leave the next operator a concise handoff.

Detailed principles: [Cook Ding](docs/principles/cook-ding.md),
[Ponytail](docs/principles/ponytail.md), and the [Zsh Quality
Rubric](docs/zsh-quality-rubric.md).

## 1. Orientation

Run these to understand the current state of the machine:
```bash
zdots-ctl status    # aggregate service status
capabilities --json  # environment contract validation
agent-guide          # detailed usage guide for all services
```

**The platform** = `zdots` (`~/.config/zsh`) + `adots` (bare repo `~/.homegit`,
work-tree `$HOME`) + `my` (`~/my`) + `vdots` (`~/.config/nvim`). This is
binding: when the operator says "the platform" or "platform-wide" without
further qualification, it means all four repos, using the per-repo
invocation table in `docs/agents/platform-sync.md`. Never assume
"zdots" alone unless the operator names it specifically.

Current component topology and PATH ownership: [docs/platform-map.md](docs/platform-map.md).

**Work-extension hook surface (Z-262).** None of the four platform repos
carries any tenant/employer identity — that lives entirely in a separate,
untracked repo at `${ZDOTS_WORK_EXT:-~/.config/zdots-work}` (own history, own
remote, never a submodule), loaded by `conf.d/31-work-ext.zsh` if present.
See §10 for the PHI-pattern overlay contract and `.zdots.local.example` for
the full env-var hook list (`ZDOTS_WORK_EXT`, `ZDOTS_K8S_DEFAULT_NS`,
`ZDOTS_APP_LOG`). adots/my/vdots have no work-extension touchpoints as of
this writing; if one is ever needed there, give it the same
gitignored-local-override treatment, never a tracked identifier.

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
colima-status socket       # just the socket path — DOCKER_HOST="unix://$(colima-status socket)"
colima-status --json | jq -r .docker_host   # same value, already unix://-prefixed
colima-status health       # exit 0 = up; exit 1 = down
```

**Never hardcode the socket path.** The socket moved from `~/.colima/` to `~/.config/colima/` in recent colima versions. Scripts that hardcode the old path silently miss the socket and burn tokens looping on false negatives. `colima-status` tries both locations and warns loudly when it finds the legacy one.

**By task:**

| Need | Tool |
|---|---|
| Multi-file reasoning | `zaider` (Aider wired to local llama.cpp); use `zpi` for read-only exploration |
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
| Cross-session agent messaging & route | `bus` (`bus route`, `bus conversations`, `bus read`) |
| Agent transit presence & layovers | `bus board`, `bus layover [preset]`, `bus in-service` |
| Inspect voicemail depot | `bus voicemail [--clear]` |
| Video/audio knowledge ingest | `zdots-ingest-media <url\|file>` (`ingest-media` skill) |
| Local audio transcription | `ztranscribe <url>` (`recipes/yt-transcribe`) |

## 4. Project Protocols

- **Tasks:** Use the `backlog` CLI. See [docs/backlog.md](docs/backlog.md).
- **Environment:** Use `ztask start <id>` when starting work to hydrate context.
- **Knowledge Base:** Use `zdots-ctx query`, `zdots-ctx query --semantic`, and `zdots-ctx hydrate` before claiming missing context. See [docs/wiki/AI-and-Knowledge-Layer.md](docs/wiki/AI-and-Knowledge-Layer.md).
- **Observability:** This is an observable session linked to the shell via `gemini-invoke`. Every tool call you make is tracked.
- **Standards:** Follow the [Zsh Quality Rubric](docs/zsh-quality-rubric.md).
- **Setup:** See [SETUP.md](SETUP.md) for new machine setup.
- **Testing:** See [docs/testing.md](docs/testing.md).

---

## 5. Shared Platform Coordination

When a task explicitly requests a zdots change, work within that scope and
trace callers before changing shared behavior. If zdots fails unexpectedly
outside the requested work, report it with `zdots-issue` and avoid an unrelated
fix. The operator owns cross-repo sequencing and service-level decisions.

```bash
zdots-issue "Short description"
zdots-issue --type question "Does zdots support X?"
zdots-issue --type request "I need X to complete Y"
```

## 6. Reference

| Service | Manager | Doc |
|---|---|---|
| AI (llama.cpp) | `llama-ctl` | [docs/llama-cpp.md](docs/llama-cpp.md) |
| Transcription | `whisper-ctl` | [README.md](README.md) |
| OTel | `otel-collector` | [docs/otel-collector-guide.md](docs/otel-collector-guide.md) |
| Observability | `openobserve-ctl` (`zsvc o2`) | [docs/openobserve.md](docs/openobserve.md) |
| Orchestrator | `zdots-ctl` | [README.md](README.md) |
| Message Bus & Coordinator | `bus-coordinator-ctl` (`bus`) | [docs/message-bus.md](docs/message-bus.md) |

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

Local inference is the default (`ZDOTS_AI_MODE=local`). Cloud calls are opt-in
through the explicit Pi and Aider lanes documented in `PI.md` and `AIDER.md`;
their credentials come from Keychain. Interactive cloud prompts are not
scrubbed, so never include PHI, secrets, or credentials.

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

Zdots has formal vocabulary. The concept registry is **live data** — built from
decision-009/Z-151, queryable via:

```bash
zdots-ctx concept <slug>              # look up a term
zdots-ctx concept resolve <word>      # resolve alias → canonical term
zdots-ctx concept <slug> --json       # machine-readable
```

`CONTEXT.md` remains the prose reference. Use exact terms consistently in code,
commits, PRs, and conversations.

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
| **Capability** | feature, service, function, operation | Discoverable facility with live availability evidence |

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

- Reference `CONTEXT.md` for prose definitions. Verify the canonical slug with
  `zdots-ctx concept resolve <word>` — the registry (decision-009/Z-151) is now live.

**In Code Comments:**

Only comment WHY, not WHAT. Use vocabulary consistently:

```bash
# Bad: "This function scrubs PHI from input"
# (too obvious; uses "scrub" as verb)

# Good: "Apply the PHI Scrubber before inference"
# (references component by name; reader can look up semantics in CONTEXT.md)
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
- To add a PHI or credential pattern, edit `etc/phi-patterns.yaml` **only**. The single sanctioned extension is the work-extension layer (`${ZDOTS_WORK_EXT:-~/.config/zdots-work}/phi-patterns.d/*.yaml`, Z-262): tenant fragments that `zdots-otel-phi-compile` merges at compile time. A fragment may add whole patterns, or add tenant-verified non-PHI route exemptions to a `redact_all_except` structural rule — it cannot edit or remove a base pattern, and the live `--probe` gate must still pass. No other file may define patterns. The registry auto-compiles at shell startup and applies to all layers.

**Audit trail:**
- Every PHI-adjacent operation emits to macOS Unified Logging: `subsystem=com.zdots category=phi-boundary`
- Query: `log show --predicate 'subsystem == "com.zdots"' --last 1h`
- This survives OTel being down and cannot be cleared without root.

**Verify posture:** `zdots-ctl check` (hard-fails on FileVault/SIP; checks AI mode, capture, history-redact, llama-server bind, model provenance).

Full policy: `backlog/docs/doc-002 - PHI-Safety-Policy.md`
