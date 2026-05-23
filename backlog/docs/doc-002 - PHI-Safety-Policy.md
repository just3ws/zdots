---
id: doc-002
title: PHI Safety Policy
type: specification
created_date: '2026-05-23 00:33'
tags:
  - phi
  - security
  - policy
---
# PHI Safety Policy

**Status:** Active  
**Applies to:** All zdots instances where `ZDOTS_CONTEXT=work` or any system that touches protected health information.

---

## 1. What Counts as PHI in This Context

The following patterns are treated as PHI and must never leave the local machine via any AI endpoint:

| Type | Pattern | Example |
|------|---------|---------|
| SSN | `\d{3}-\d{2}-\d{4}` | 123-45-6789 |
| MRN | `MRN\s*:?\s*\d+` | MRN: 00123456 |
| DOB | `(DOB\|date.of.birth)\s*:?\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}` | DOB: 01/15/1980 |
| Name in clinical context | Name adjacent to MRN, diagnosis, or medication terms | Patient: John Smith, Dx: ... |
| Connection strings | `postgresql://[^@]+@` | postgresql://user:pass@host/db |

Redaction markers: `[REDACTED-SSN]`, `[REDACTED-MRN]`, `[REDACTED-DOB]`, `[REDACTED-CONN]`

---

## 2. Permitted vs. Forbidden Data Flows

### Permitted — local AI only
- Shell command analysis (no PHI content)
- Code review and refactoring
- Documentation generation from non-PHI source
- Architecture reasoning
- Tool selection and configuration

### Forbidden — never to any AI endpoint
- Raw patient records or record excerpts
- Any content matching PHI patterns above
- Database query results from clinical systems
- Log lines containing patient identifiers
- Error messages that may embed PHI from upstream systems

### Rule
When `ZDOTS_AI_MODE=local`, the AI endpoint **must** resolve to loopback (127.x) or RFC-1918 (10.x, 172.16–31.x, 192.168.x). Any other target is a hard block, not a warning.

---

## 3. Capture Opt-In Contract

Session capture (`zdots-ctx capture`) is **disabled by default** when `ZDOTS_CONTEXT=work`.

To enable:
1. Set `ZDOTS_CAPTURE_ENABLED=1` in `.zdots.local` — explicit operator intent
2. All captured content is scrubbed through the PHI pattern filter before DB write
3. Scrubbed markers are permanent — original values are not stored anywhere
4. Captured lessons are encrypted at rest (see DB encryption policy)

The scrubber is the first layer, not the last. Do not rely on it as the sole control. Avoid capturing content that originates from clinical systems.

---

## 4. Zero-AI Fallback Principle

The system must be fully operational with `ZDOTS_AI_MODE=none`. This is not a degraded state — it is the baseline safe state for:
- Unknown corporate proxy environments
- Air-gapped or restricted networks
- Any time the local model is unavailable

All AI-touching commands must exit cleanly with a clear message under `ZDOTS_AI_MODE=none`. No hangs, no timeouts, no opaque curl errors.

---

## 5. Model Provenance

The local inference model must be verified against a tracked sha256 manifest before use. An unverified model file must not be used for inference. This ensures the model running on the regulated machine is exactly the expected artifact.

---

## 6. Database Encryption

The `my` PostgreSQL database stores lessons, methodologies, and session residue. Sensitive text columns are encrypted at rest using pgcrypto symmetric encryption (`pgp_sym_encrypt`). The encryption key (`ZDOTS_DB_ENCRYPTION_KEY`) lives in `.zdots.secrets` only — never committed. FileVault provides the disk layer; pgcrypto provides the application layer.

---

## 7. Shell History

Shell history is a liability in a PHI environment. The `zshaddhistory` hook:
- Redacts PHI patterns in commands before history write
- Suppresses entries containing connection strings entirely
- Accepts site-specific patterns via `ZDOTS_HISTORY_REDACT_PATTERNS` in `.zdots.local`

---

## 8. Operating Posture Summary

| Control | Default (work) | Override mechanism |
|---------|---------------|-------------------|
| AI mode | `local` | `.zdots.local` only |
| AI locality enforcement | enforced | not bypassable in local mode |
| Capture | disabled | `ZDOTS_CAPTURE_ENABLED=1` in `.zdots.local` |
| History redaction | on | `ZDOTS_HISTORY_REDACT=0` in `.zdots.local` |
| DB encryption | required | `ZDOTS_DB_ENCRYPTION_KEY` in `.zdots.secrets` |
| Model verification | enforced | not bypassable |

---

## 9. Compliance Note

This policy establishes a technical baseline consistent with HIPAA minimum necessary and safeguard principles. It is not a substitute for a formal organizational HIPAA compliance program. The operator remains responsible for ensuring their full workflow meets applicable regulatory requirements.
