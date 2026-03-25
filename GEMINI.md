# GEMINI.md

Gemini-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines and performance standards.

## Gemini Context
- This environment is optimized for `gemini-cli` via the `gm` alias.
- To maintain token efficiency, always proxy high-output commands through `rtk` (e.g., `rtk pnpm build`).
- Use `tokei` for quick codebase orientation before performing deep analysis.
- Respect the performance budget (< 0.08s) when suggesting shell modifications.
