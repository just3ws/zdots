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
