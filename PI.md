# PI.md

Pi-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, **RTK token-optimization rules**, and **PHI Operating Mode** (Section 8 — non-negotiable on work machines).

Pi is `@earendil-works/pi-coding-agent` — a session-aware AI coding agent with built-in tools (read, bash, edit, write). It runs locally via llama.cpp, with full PHI boundary enforcement.

## Invocation

| Command | Purpose |
|---------|---------|
| `zpi` | Interactive Pi session |
| `zpi "question"` | One-shot question |
| `zpi -p "prompt"` | Non-interactive, print output only |
| `zmorning` | Session-open ritual: brief + Pi orientation |
| `zmorning --brief` | Brief only, no Pi |

`zpi` auto-configures `PI_TELEMETRY=0`, `PI_CODING_AGENT_SESSION_DIR` (XDG), and enforces the AI boundary (`ZDOTS_AI_MODE`, RFC-1918 endpoint check).

## Pi vs Aider — the boundary

These tools are complementary, not competing. The rule is simple:

| Tool | Use for |
|------|---------|
| `zpi` | Exploration, reading, explaining, planning, asking "how should we…" |
| `zaider` | Editing files, writing code, committing — any **mutation** |

Pi reads and reasons. Aider writes and commits. Pi's output becomes Aider's input.

**Workflow:**
```
zpi "explain the capture pipeline and identify gaps"   # read + reason
zpi "how should we fix the phi_scrub return value?"    # plan
zaider --message "fix phi_scrub to always return 0"    # execute + commit
```

Pi does NOT own git. Any file changes Pi suggests should be reviewed and applied via `zaider` or reviewed manually. Do not run `pi` with write permissions in production paths.

## Context Budget (7B model — 32k total)

Same constraints as Aider — this is the same underlying model.

| Slot | Tokens | Notes |
|------|--------|-------|
| System prompt | ~1k | Fixed |
| Session history | ~4k | Grows across turns |
| File reads | ~20k | Pi reads files with its tools |
| Output | ~2k | Hard ceiling from llama.cpp |

**Keep sessions focused.** Start a new `zpi` session for each distinct topic.

## ZLE Widgets

Two inline widgets are available without launching a full session:

| Binding | Widget | What it does |
|---------|--------|--------------|
| `Alt-e` | explain | Explains the command currently in the buffer |
| `Alt-f` | fix | Diagnoses the last command that exited non-zero |

Both call the local inference endpoint directly — ~1-3s response time. Results appear below the prompt; your buffer is preserved.

## PHI Safety

- `PI_TELEMETRY=0` is always set by `zpi()` — no telemetry from a PHI-adjacent machine.
- Session history lands in `${XDG_STATE_HOME}/pi/agent/sessions` — never in the project directory.
- All Pi sessions are gated by `zdots_ai_gate` — exit 2 in `ZDOTS_AI_MODE=none`.
- Endpoint assertion enforces RFC-1918 in `local` mode — Pi cannot reach cloud endpoints unless `ZDOTS_AI_MODE=cloud` is explicitly set.
- Do NOT paste patient record excerpts into Pi. The PHI scrubber is the first layer, not the last.

## Platform Control

```bash
zdots-ctl check       # deep health diagnostic — run first when something is wrong
zdots-ctl up          # start llama.cpp and all services
llama-ctl status      # check llama.cpp specifically
```

## Session Management

Pi sessions are stored as files in `${XDG_STATE_HOME}/pi/agent/sessions`. Clean old sessions periodically:

```bash
ls "${XDG_STATE_HOME}/pi/agent/sessions"
```

## Configuration

| File | Purpose |
|------|---------|
| `~/.pi/agent/settings.json` | Default provider/model |
| `~/.pi/agent/models.json` | Provider definitions (llamacpp, ollama) |
| `providers/ai/pi.zsh` | Zsh integration, boundary enforcement, `zpi()` |

The `llamacpp` provider in `models.json` points at `http://127.0.0.1:11500/v1` — the local llama.cpp OpenAI-compatible endpoint. Changing `ZDOTS_AI_ENDPOINT` in `.zdots.local` does **not** automatically update Pi's `models.json`; they must be kept in sync manually.
