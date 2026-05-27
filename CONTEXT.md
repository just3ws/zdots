# CONTEXT.md — Zdots Domain Glossary

Terms used in code, docs, and agent instructions. Use exact names.

---

## Platform Service

Any long-running process managed by `zdots-ctl`: startable, stoppable, health-probeable, and tracked in `zdots-ctl status --json`. The umbrella category — does not imply a tier.

**Core Service** — a Platform Service zdots itself depends on to function. Always present on any zdots host. Examples: llama.cpp (AI inference), whisper (transcription), otel-collector (observability), context engine (knowledge persistence).

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

**Scope:** all text entering inference (`ai-query`, `zdots-ask`) or persistence (`zdots-ctx` DB writes and captured session data).

**Not in scope:** observability data, span payloads, and trace metadata — these use `zdots_trace_redact` (providers/trace).

---

## PHI Pattern Registry

The canonical list of PHI redaction patterns and their risk weights, defined once and consumed by all enforcement contexts.

**Source:** `etc/phi-patterns.yaml` — each entry carries a `name`, POSIX `regex`, `replace` string, and optional `weight`.

**Compilation:** `lib/phi_scrubber.bash` compiles the YAML into `PHI_SED_SCRIPT` at first use via `_phi_load_patterns`. Fails hard if `yq` is absent. The compiled script is cached for the shell session.

**Consumers:**
- `phi_scrub` — applies `PHI_SED_SCRIPT` via sed (redaction)
- `aiq_scan` — reads entries with `weight` set for risk scoring
- `conf.d/55-phi-history.zsh` — reads compiled script via `phi_scrub`

**Invariant:** a new PHI pattern type requires exactly one file edit (`etc/phi-patterns.yaml`). No other file should define PHI patterns.

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

## Virtuous Loop

The positive feedback cycle that makes AI-assisted work improve over time:

1. **Work** — do real work in shell sessions with AI agents.
2. **Capture** — `zdots-ctx capture` distills the session into Session Residue.
3. **Curate** — review Session Residue, promote to Lessons; synthesize Lessons into Methodologies. Curation can be done via Pi interacting with the Knowledge Base directly.
4. **Infer** — future AI calls (`zdots-ctx hydrate`, `zdots-ask`) pull curated context from the Knowledge Base, improving response quality.
5. Repeat — each cycle deposits better signal and withdraws sharper context.

The loop is only valuable if curation happens. Uncurated session residue (`processed_into_docs_at` is null) is raw material, not signal.

**Trust property:** the Virtuous Loop is what makes `zdots-*` commands safe to auto-permit in local AI agents. Because all agent actions are captured, curated, and fed back as lessons, unexpected or wrong behavior becomes a learning event rather than an invisible failure. The loop is the governance mechanism — not just policy.
