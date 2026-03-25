# CLAUDE.md

Claude-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines and performance standards.

## Claude Context
- This environment is optimized for `claude-code` via the `cl` alias.
- When running long commands, prefer `rtk <command>` to keep your context window clean.
- Use `repomix` to ingest the entire project structure if high-density context is required.

<!-- rtk-instructions v2 - HISTORY AWARE -->
# RTK (Rust Token Killer) - History-Aware Optimizations

**Golden Rule:** Prefix high-output commands with `rtk` to minimize token noise.

## 1. High-Volume JavaScript/TS Workflow (90% savings)
You frequently run deep verification suites. Always use these:
```bash
rtk pnpm verify:all     # Summarizes massive lint/test/typecheck logs
rtk pnpm playthrough:*  # Collapses long QA/Playwright trace logs
rtk pnpm install        # Compact dependency confirmations
rtk tsc                 # Groups TypeScript errors by file/code
```

## 2. Infrastructure & Cloud (85% savings)
Summarize noisy deployment and log events:
```bash
rtk fly deploy          # Highlights deployment events, hides progress spam
rtk fly logs            # Deduplicates log streams with hit counts
rtk docker logs         # Filters repetitive container output
```

## 3. Git & GitHub (60-80% savings)
Harden your context against massive diffs and logs:
```bash
rtk git status          # Ultra-compact status
rtk git diff            # Summarizes changes, prevents context flooding
rtk git log             # Compact commit history
rtk gh pr checks        # Clean table of CI status
```

## 4. Metadata & Analysis
```bash
rtk tokei               # Instant codebase orientation
rtk summary <cmd>       # Smart summary of any command output
rtk json <file>         # Schema-only view of large JSON files
```

## Meta Commands
- `rtk gain`: View your token savings statistics.
- `rtk discover`: Detect missed opportunities for `rtk` usage in this session.
<!-- /rtk-instructions -->
