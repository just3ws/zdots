# CLAUDE.md

Claude-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, and **RTK token-optimization rules**.

## Claude Context
- This environment is optimized for `claude-code` via the `cl` alias.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#rtk-rust-token-killer---history-aware-optimizations) for all high-output commands.
- Use `repomix` to ingest the entire project structure if high-density context is required.
