# CLAUDE.md

Claude-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines and performance standards.

## Claude Context
- This environment is optimized for `claude-code` via the `cl` alias.
- When running long commands, prefer `rtk <command>` to keep your context window clean.
- Use `repomix` to ingest the entire project structure if high-density context is required.
