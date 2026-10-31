---
name: zdots-gemini
scope: zdots repository
audience: Gemini CLI
inherits: AGENTS.md
---

# Gemini CLI

Repository-wide policy is in [AGENTS.md](AGENTS.md). This file contains only
Gemini-specific operation.

- Use `gm` for the configured Gemini CLI integration. Use `gemini-invoke` when
  session tracing through the local observability stack is needed.
- Run `capabilities --json` when a task depends on a specific platform
  capability; use `agent-guide` for current service and endpoint discovery.
- Use `ack` when it provides the needed search; `rg` is the maintained fallback.
- Follow the task's local data boundary. Never put PHI, credentials, or secret
  values into a remote Gemini session.

See [AGENTS.md](AGENTS.md) for shared safety and workflow rules and
[docs/tooling.md](docs/tooling.md) for the command catalog.
