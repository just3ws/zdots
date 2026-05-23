# Security Policy: The Zdots Control Plane

## Security Baseline

Zdots enforces a high-security baseline for the shell environment:

1. **Restricted File Creation**: `umask 077` is enforced early in the boot sequence. All files created by the shell (caches, history, logs) are only accessible by the current user.
2. **State Protection**: The `XDG_STATE_HOME/zsh` directory is restricted to `700` and trace files to `600` permissions.
3. **Automated Redaction**: The observability stack automatically masks sensitive command-line flags (e.g., `-p`, `--password`, `--token`) in both local and remote telemetry.

## PHI Safety Controls (Operation Martian)

Zdots enforces defense-in-depth for PHI-adjacent workloads across six layers:

| Layer | Mechanism |
|---|---|
| **Secret storage** | macOS Keychain via `zdots-keychain`; no plaintext secrets in repo |
| **AI locality** | `lib/ai_boundary.bash`: `ZDOTS_AI_MODE=local` blocks non-RFC-1918 endpoints at the function boundary |
| **PHI scrubbing** | `lib/phi_scrubber.bash`: SSN, MRN, DOB, connection strings redacted before every AI call |
| **History redaction** | `zshaddhistory` hook: PHI patterns stripped from shell history |
| **DB encryption** | pgcrypto `pgp_sym_encrypt` on `lessons.content`, `methodologies.content`, `session_residue.{summary,intent,result}` — key from Keychain |
| **Audit trail** | `lib/audit_log.bash`: every PHI-adjacent event written to macOS Unified Logging (`com.zdots/phi-boundary`) |

**Verify posture:** `zdots-ctl check` (with `ZDOTS_CONTEXT=work`) hard-fails on FileVault/SIP disabled; warns on firewall, AI mode, capture, history-redact, llama-server bind, and model provenance.

**Query audit log:**
```bash
log show --predicate 'subsystem == "com.zdots"' --last 1h
log stream --predicate 'subsystem == "com.zdots" AND category == "phi-boundary"'
```

**Model provenance:** `lib/llama-models.sha256` contains tracked SHA256 hashes. `llama-ctl start` and `llama-ctl model-verify` refuse to run with a mismatched model file.

## Guardrails & Validation

- **Secret Scanning**: `bin/secret-scan` is run as part of the primary regression suite and in CI. It uses ripgrep to scan the codebase for leaked high-confidence patterns (AWS keys, GitHub PATs, private keys).
- **Compliance Testing**: `tests/security.bats` provides automated regression testing for the security baseline.

## Supported Branch

- `main` is the supported branch for security fixes.

## Reporting a Vulnerability
...
1. Use GitHub's private vulnerability reporting for this repository when available (`Security` tab -> `Report a vulnerability`).
2. If private reporting is unavailable, open an issue with minimal detail and request a private contact channel.
3. Do not post credentials, tokens, private keys, or exploit proof-of-concept details in public issues.

## Secret Exposure Response

If you discover an exposed credential in this repository:

1. Revoke or rotate the credential immediately.
2. Remove it from current files.
3. Rewrite git history to purge the secret from historical commits.
4. Force-push cleaned history and notify collaborators to re-clone.
