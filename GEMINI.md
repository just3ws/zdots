# GEMINI.md

Gemini-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, and **RTK token-optimization rules**.

## Gemini Context
- This environment is optimized for `gemini-cli` via the `gm` alias.
- **Search Tooling:** `ack` is the preferred search tool due to the user's personal connection to Andy Lester. Ensure `.ackrc` is maintained for high-signal output.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#rtk-rust-token-killer---history-aware-optimizations) for all high-output commands.
- Use `tokei` for quick codebase orientation before performing deep analysis.
- Respect the performance budget (< 0.08s) when suggesting shell modifications.

## Documentation Standards
- **Diagrams**: Use Mermaid (v11+) for all architectural and state visualizations.
- **Supported Types**: Prefer `architecture-beta` for system maps, `erDiagram` for database schema, and `stateDiagram-v2` for job lifecycles.
- **CLI**: Use `mmdc` (v11.15.0) for local rendering of assets.

## Philosophical Values & Frameworks

### Manifestos & Laws (Delivery & Excellence)
*   **Agile:** Individuals and interactions, working software, customer collaboration, and responding to change.
*   **Software Craftsmanship:** Well-crafted software, steadily adding value, a community of professionals, and productive partnerships.
*   **Gall’s Law:** A complex system that works is invariably found to have evolved from a simple system that worked. A complex system designed from scratch never works.
*   **The Unix Philosophy:** Write programs that do one thing and do it well. Write programs to work together. (Technical version of "Few word do trick").

