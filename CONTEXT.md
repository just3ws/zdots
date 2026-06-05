# CONTEXT.md — Zdots Domain Glossary

Terms used in code, docs, and agent instructions. Use exact names.

---

## Platform Service

Any long-running process managed by `zdots-ctl`: startable, stoppable, health-probeable, and tracked in `zdots-ctl status --json`. The umbrella category — does not imply a tier.

**Core Service** — a Platform Service zdots itself depends on to function. Always present on any zdots host. Examples: llama.cpp (AI inference), whisper (transcription), otel-collector (observability), context engine (knowledge persistence), the Worker (async job drain).

**Cache Service** — a Platform Service that improves throughput but degrades gracefully when absent. zdots continues to operate if a Cache Service is down, with automatic fallback to a slower path. Current instance: Redis (command analytics write buffer; falls back to async SQLite when unreachable). Tracked in `zdots-ctl status` and warned (not failed) in `zdots-ctl check`.

**Hosted Service** — a Platform Service zdots manages on behalf of a project or workload. zdots does not depend on it; it is host-profile-selected. Examples: wwworkremote (job search automation), Phalanx Duel (game management).

A service can hold both roles simultaneously: context engine is a Core Service (zdots-ctx depends on it) and a Hosted Service (external tools consume it directly).

**Hosted Service interaction patterns:**
- **CLI Pipeline** — caller passes input on the command line; the service owns the automation. Pattern: `command <input>` → async processing. Examples: video transcription, wwworkremote.
- **AI Interface** — MCP-backed; AI mediates all interactions with the system. Examples: Phalanx Duel.

---

## Message Hygiene Pipeline

The ordered sequence of transformations applied to any text before it enters the system for inference or persistence.

**Stages (must run in order):**

1. **Normalize** — strip format artifacts (null bytes, ANSI escape sequences, CRLF, C0 control characters). Must run first: artifacts can cause PHI patterns to miss matches.
2. **PHI Scrub** — remove protected health information (SSN, MRN, DOB, database connection strings with credentials).

**Interface:** `zdots_message_hygiene` in `lib/message_hygiene.bash` — stdin → stdout. Always runs the full pipeline. Callers never compose stages individually.

**Failure:** returns non-zero if PHI protection is unavailable (yq absent, registry missing) or if input contains a suppress-flagged pattern. Callers must treat non-zero exit as a hard failure — do not continue inference or persistence.

**Scope:** all text entering inference (`ai-query`, `zdots-ask`) or persistence (`zdots-ctx` DB writes and captured session data).

**Not in scope:** observability data, span payloads, and trace metadata — these use `zdots_trace_redact` (providers/trace).

---

## PHI Pattern Registry

The canonical list of all sensitive-pattern redaction and suppression rules, defined once and consumed by all enforcement contexts. Scope covers PHI (SSN, MRN, DOB, connection strings) and credential patterns (inline `key=value`, flag-style `--flag value`).

**Source:** `etc/phi-patterns.yaml` — each entry carries a `name`, POSIX `regex`, `replace` string, optional `weight`, and optional `suppress: true` flag.

**Suppress flag:** patterns with `suppress: true` are treated differently by each enforcement layer:
- `phi_scrub` — fails hard (non-zero, no stdout) when input matches a suppress pattern.
- `phi_should_suppress(line)` — returns 0 (true) if the line matches any suppress pattern; used as a fast no-fork pre-flight in the history hook.
- History hook — calls `phi_should_suppress` first; if true, drops the history entry silently.
- Analytics hook — calls `phi_should_suppress` first; if true, skips the SQLite insert.

**Compilation:** `lib/phi_scrubber.bash` compiles the YAML at first use via `_phi_load_patterns`. Fails hard if `yq` is absent or the registry is missing. `phi_scrubber_init()` triggers eager compilation at shell startup. Two caches are produced: `_PHI_SED_ARGS` (redact patterns, for sed) and `_PHI_SUPPRESS_PATTERN` (suppress patterns, OR'd ERE for `=~` checks).

**Consumers (bash):**
- `phi_scrub` — applies `_PHI_SED_ARGS` via sed; fails hard on suppress-pattern match
- `phi_should_suppress` — fast `=~` check against `_PHI_SUPPRESS_PATTERN`; no fork
- `aiq_scan` — reads entries with `weight` set for risk scoring
- `conf.d/55-phi-history.zsh` — sources scrubber; uses `phi_should_suppress` + `phi_scrub`
- `conf.d/56-cmd-analytics.zsh` — sources scrubber; uses `phi_should_suppress` + `phi_scrub`

**Consumers (Ruby):**
- `Zdots::AI::PhiScrubber` (`lib/zdots/ai/phi_scrubber.rb`) — the Ruby twin. `.call` redacts; raises `SuppressedError` on a suppress-flagged pattern. `.suppressed?` is the predicate twin of `phi_should_suppress`.
- `Zdots::AI::Pipeline` maps `SuppressedError` → `Failure[:phi_suppressed]`, so both inference and embedding abort (never redact-and-continue) on a suppress match.

**Two implementations, one behaviour:** the bash and Ruby scrubbers both compile this registry and **must agree** — same redactions, and suppress means fail-hard in both. They are pinned by the cross-implementation contract test (`spec/zdots/ai/phi_contract_spec.rb`); changing one without the other breaks the build.

**Invariant:** a new sensitive pattern type requires exactly one file edit (`etc/phi-patterns.yaml`). No other file defines PHI or credential patterns.

---

## AI Invocation Interface

The seam through which all local AI inference is called. Lives in `lib/ai-invoke.bash`. All callers use these functions — never call `ai-query` directly from lib code or shell functions.

**`zdots_ai_infer_raw()`** — stdin → stdout (raw text).
- Gate check + locality assertion (fails hard if `ZDOTS_AI_MODE=none` or endpoint is non-local).
- Runs `zdots_message_hygiene` on input (normalize → PHI scrub). This function owns hygiene; callers do not pre-scrub.
- Uses `--mode raw` (no safe-extract wrapping): caller constructs the full prompt, so there is no untrusted data block to isolate.
- Used by: `zdots-ask` (domain-routed prompts), ZLE widgets `_zdots_zle_ai_explain` / `_zdots_zle_ai_fix` (buffer explain/fix).

**`zdots_ai_distill()`** — stdin → stdout (JSON).
- Calls `zdots_ai_infer_raw` internally.
- Requests structured JSON output; validates the response parses.
- Used by: `zdots-ctx capture` (distillation of session history/traces).

**Caller contract:** callers build and own the prompt. These functions own gate, hygiene, submission, and output parsing. Neither function constructs prompts.

---

## Command Analytics

The real-time capture layer that records every shell command with exit code, duration, CWD, and session context. Feeds the Knowledge Base via `zdots-ctx sync-history`.

**Write path:** `conf.d/56-cmd-analytics.zsh` captures commands in `_zca_precmd`. Primary write target is Redis (`zdots:cmds:<session_id>`, TTL 24h, synchronous RPUSH). Falls back to async SQLite (`$XDG_STATE_HOME/zdots/history.sqlite3`) when Redis is unreachable.

**Drain path:** `zdots-ctx sync-history` calls `_drain_redis_to_sqlite` before invoking `zdots-brain sync-history`. The drain moves all Redis-buffered entries into SQLite in a single transaction per key, then DELs the key. This ensures Redis-written entries reach PostgreSQL on the next sync.

**PHI contract:** all commands pass through `_zca_redact` (which calls `phi_should_suppress` + `phi_scrub`) before any write. Suppress-flagged commands (connection strings) are dropped entirely — `_ZCA_CMD` is cleared and the function returns early. No unredacted command ever reaches Redis, SQLite, or PostgreSQL.

**Enable:** `ZDOTS_CMD_ANALYTICS=1` in `.zdots.local`. Off by default. Disabled unconditionally on work machines (`.zdots.work` enforces `ZDOTS_CMD_ANALYTICS=0`).

---

## Knowledge Layer

The layer above the platform services that makes zdots more than a shell config. Encompasses: zdots-brain (gateway), the Knowledge Base (PostgreSQL), the Knowledge Vault (Obsidian source documents), and the Virtuous Loop (the feedback cycle that keeps it healthy).

Previously called "Intelligence Suite" in `.zdots.env` — that name is retired. Use **Knowledge Layer** everywhere.

The Knowledge Layer is local-only. Nothing in it reaches cloud services.

---

## Knowledge Base

The personal "second brain" stored in the `my` PostgreSQL database. Contains engineering lessons, aesthetic preferences, insights, and reference material accumulated over time. Not a product or shared system — a personal knowledge layer.

**Gateway:** `zdots-brain` (Ruby CLI, `sbin/zdots-brain`) is the sole owner of read/write access. `zdots-ctx` is the shell interface to `zdots-brain`. No other tool writes to the knowledge base directly.

**Stored entities (in order of abstraction):**
- **Session Residue** — raw distillation of a captured shell session: `intent`, `result`, `summary`, linked by `trace_id`. Written by `zdots-ctx capture`. Has a `processed_into_docs_at` lifecycle flag; unset means not yet curated.
- **Lesson** — a curated knowledge unit: `content`, `context`, `tags`. Can be promoted from Session Residue or authored directly (no source trace required).
- **Methodology** — a synthesized, higher-level knowledge artifact: `slug`, `title`, `content`, `tags`. Authored deliberately; represents stable principles rather than individual session observations.

---

## Knowledge Vault

The Obsidian-managed document directory that is the source of truth for the Knowledge Base. Lives at `~/my/knowledge/`. Documents are edited in Obsidian; ingestion into PostgreSQL is a derived operation — the markdown files are always authoritative.

**Structure:**
- `inbox/` — fast capture; unprocessed drafts; never ingested until promoted
- `lessons/` — atomic curated knowledge units; maps to the `lessons` table
- `methodologies/` — synthesized principles and reference documents; maps to the `methodologies` table
- `references/` — external source documents (manifestos, standards); maps to the `methodologies` table

**Frontmatter contract** (required for ingestion): `type`, `tags[]`, `slug`. The `slug` is the stable upsert key — re-ingesting a file updates the existing DB record without creating a duplicate.

**Correction discipline:** corrections discovered in Pi conversations are applied by editing the source document in Obsidian and re-ingesting. The database is never edited directly.

---

## Worker

The Core Service that drains the async job queue (the `jobs` table in the `my` database). Without it, jobs are enqueued but never processed, so the queue backs up silently and the Knowledge Base stops gaining embeddings, distillations, and doc syncs.

**Implementation:** `sbin/zdots-brain worker` — an infinite `claim → perform → sleep 5` loop. Claims one job at a time via the `claim_next_job` PL/pgSQL function, dispatches by type through the Jobs registry, and marks the job complete or failed.

**Job types:** `embed` (vector generation from payload text), `distill` (transcript → Lesson), `docs_sync` (Session Residue → maintained docs), `transcription`.

**Lifecycle:** managed as a Platform Service. `bin/zdots-worker` is the authoritative ctl (install/start/stop/restart/status/health/logs); control it through `zsvc <verb> worker`. It runs under a user-domain launchd agent (`com.zdots.worker`, KeepAlive + RunAtLoad) so the queue always drains and the worker restarts on crash or at login.

**Secret handling:** the launchd `run` entry point loads `ZDOTS_DB_ENCRYPTION_KEY` from the Keychain at runtime (needed by `distill` jobs for encrypted Lesson writes). The key is **never** written into the plist — the plist carries only `HOME`, `PATH`, and `ZDOTDIR`.

**Health:** liveness is "launchd process alive" — there is no endpoint to probe. A worker that is alive but wedged (not draining) is not yet detected; queue-depth-over-time health is a future enhancement.

**Stale jobs:** a worker that dies mid-job leaves a row in `running`. `zdots-ctx clear-stale-jobs [interval]` (PL/pgSQL `clear_stale_jobs`) resets rows stuck in `running` past the interval to `failed`. KeepAlive restart does not reclaim them — clearing is a separate step.

---

## Virtuous Loop

The positive feedback cycle that makes AI-assisted work improve over time:

1. **Work** — do real work in shell sessions with AI agents.
2. **Capture** — `zdots-ctx capture` distills the session into Session Residue.
3. **Curate** — review Session Residue, promote to Lessons; synthesize Lessons into Methodologies. Curation can be done via Pi interacting with the Knowledge Base directly.
4. **Infer** — future AI calls (`zdots-ctx hydrate`, `zdots-ask`) pull curated context from the Knowledge Base, improving response quality.
5. Repeat — each cycle deposits better signal and withdraws sharper context.

The loop is only valuable if curation happens. Uncurated session residue (`processed_into_docs_at` is null) is raw material, not signal.

**Trust property:** the Virtuous Loop is what makes `zdots-*` commands safe to auto-permit in local AI agents. Because all agent actions are captured, curated, and fed back as lessons, unexpected or wrong behavior becomes a learning event rather than an invisible failure. The loop is the governance mechanism — not just policy.
