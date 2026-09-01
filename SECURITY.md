# Security Policy

This is a personal configuration repository, maintained by one person, best-effort.

## Reporting a vulnerability

Please **do not open a public issue** for security-sensitive reports.

Use GitHub's private vulnerability reporting:
**[Report a vulnerability](https://github.com/just3ws/zdots/security/advisories/new)**
(Security tab → "Report a vulnerability").

Expect an acknowledgement within a week. There is no bug bounty.

## Scope

In scope: anything in this repository that could expose secrets, execute
untrusted code, or weaken the machine it configures — for example a `bin/`
script that mishandles credentials, a workflow that leaks `GITHUB_TOKEN`, or a
default that disables a protection.

Out of scope: third-party tools this repo installs or wraps (report those
upstream), and the security of a machine that has deviated from the documented
setup.

## What this repo already does

- **Secrets never committed.** `bin/secret-scan` (a Go scanner with an
  externalised pattern registry) runs in CI on every push and is expected
  locally before any commit. GitHub secret scanning + push protection are on.
- **No cloud by default.** AI inference is local (`ZDOTS_AI_MODE=local`); the
  AI boundary refuses non-loopback endpoints in local mode.
- **Sensitive-data operating mode.** A documented posture for running near
  regulated data — local-only inference, a redaction pipeline before any
  outbound call, an audit trail to macOS Unified Logging.
- **Least-privilege CI.** Workflows declare `permissions: contents: read`.

See `AGENTS.md` §10 for the full operating-mode contract.
