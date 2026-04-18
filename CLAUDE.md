# CLAUDE.md

Claude-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, and **RTK token-optimization rules**.

## Platform Control

`zdots-ctl` is the single command to manage the entire local platform. Use it exclusively for service orchestration — do not call `local-ci`, `otel-collector`, or `llama-ctl` start/stop directly unless operating on a specific service in isolation.

```bash
zdots-ctl check        # deep health diagnostic (run first when something is wrong)
zdots-ctl status       # live status of all services
zdots-ctl up           # start everything in dependency order
zdots-ctl down         # stop everything cleanly
zdots-ctl reset        # full restart
zdots-ctl install      # first-time setup on a new workstation
```

## Claude Context
- This environment is optimized for `claude-code` via the `cl` alias.
- Follow the **RTK** guidance in [AGENTS.md](AGENTS.md#rtk-rust-token-killer---history-aware-optimizations) for all high-output commands.
- Use `repomix` to ingest the entire project structure if high-density context is required.
