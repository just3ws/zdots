# Security Policy

## Supported Branch

- `master` is the supported branch for security fixes.

## Reporting a Vulnerability

1. Use GitHub's private vulnerability reporting for this repository when available (`Security` tab -> `Report a vulnerability`).
2. If private reporting is unavailable, open an issue with minimal detail and request a private contact channel.
3. Do not post credentials, tokens, private keys, or exploit proof-of-concept details in public issues.

## Secret Exposure Response

If you discover an exposed credential in this repository:

1. Revoke or rotate the credential immediately.
2. Remove it from current files.
3. Rewrite git history to purge the secret from historical commits.
4. Force-push cleaned history and notify collaborators to re-clone.
