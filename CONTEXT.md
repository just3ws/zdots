# CONTEXT.md — Zdots Domain Glossary

Terms used in code, docs, and agent instructions. Use exact names.

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
- Runs `zdots_message_hygiene` on input.
- Submits without trust-boundary wrapping (assumes input is pre-scrubbed).
- Used by: `zdots-ask` (domain-routed prompts), ZLE widgets `_zdots_zle_ai_explain` / `_zdots_zle_ai_fix` (buffer explain/fix).

**`zdots_ai_distill()`** — stdin → stdout (JSON).
- Calls `zdots_ai_infer_raw` internally.
- Requests structured JSON output; validates the response parses.
- Used by: `zdots-ctx capture` (distillation of session history/traces).

**Caller contract:** callers build and own the prompt. These functions own gate, hygiene, submission, and output parsing. Neither function constructs prompts.
