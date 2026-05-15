# GEMINI.md

Gemini-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, and **RTK token-optimization rules**.

## Gemini Context
- This environment is optimized for `gemini-cli` via the `gm` alias.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#rtk-rust-token-killer---history-aware-optimizations) for all high-output commands.
- Use `tokei` for quick codebase orientation before performing deep analysis.
- Respect the performance budget (< 0.08s) when suggesting shell modifications.

## Documentation Standards
- **Diagrams**: Use Mermaid (v11+) for all architectural and state visualizations.
- **Supported Types**: Prefer `architecture-beta` for system maps, `erDiagram` for database schema, and `stateDiagram-v2` for job lifecycles.
- **CLI**: Use `mmdc` (v11.15.0) for local rendering of assets.
