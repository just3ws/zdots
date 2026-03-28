# Security Policy: The Zdots Control Plane

## Security Baseline

Zdots enforces a high-security baseline for the shell environment:

1. **Restricted File Creation**: `umask 077` is enforced early in the boot sequence. All files created by the shell (caches, history, logs) are only accessible by the current user.
2. **State Protection**: The `XDG_STATE_HOME/zsh` directory is restricted to `700` and trace files to `600` permissions.
3. **Automated Redaction**: The observability stack automatically masks sensitive command-line flags (e.g., `-p`, `--password`, `--token`) in both local and remote telemetry.

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
