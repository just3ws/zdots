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

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
