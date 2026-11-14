---
name: zdots-omp
scope: zdots repository
audience: Oh-My-Pi (omp)
inherits: AGENTS.md
---

# Oh-My-Pi (`zomp`) & Multi-Account Loopback Gateway

Repository-wide policy is in [AGENTS.md](AGENTS.md). This file defines
Oh-My-Pi (`omp` / `zomp`) as the primary AI surface and multi-account model
routing across **Home** and **Work** environments. See also
[docs/agents/ai-surface.md](docs/agents/ai-surface.md).

## 1. Execution Lanes (`zomp`)

| Command | Posture | Routing | Allowed Context |
|---|---|---|---|
| `zomp` | Strictly Local | `default`, `smol`, `slow`, `plan` → `llamacpp/local` (`127.0.0.1:11500/v1`) with `--offline --no-judge --no-spotlight` | Home & Work (`ZDOTS_CONTEXT=work`) |
| `zomp --hybrid` | Hybrid Local + Frontier Multi-Account | `smol` → `llamacpp/local` ($0/zero quota burn); `default`/`plan`/`slow` → multi-account frontier pool with automatic `429` rollover (`etc/omp/config.home.yml`) | Home only (blocked on `ZDOTS_CONTEXT=work`) |
| `zomp --or` | Explicit OpenRouter + Local Smol | `smol` → `llamacpp/local`; `default` → `openrouter/$ZDOTS_OR_MODEL` | Home only (blocked on `ZDOTS_CONTEXT=work`) |
| `zomp --work-gateway` | Corporate Internal Gateway + Local Smol | `smol` → `llamacpp/local`; `default` → `$ZDOTS_WORK_AI_GATEWAY_URL` | Work (`ZDOTS_CONTEXT=work`) |

## 2. Home vs. Work Operating Model

| Environment | Primary Interactive Surface | Local LLM Role | Frontier / Cloud Access |
|---|---|---|---|
| **Work (`ZDOTS_CONTEXT=work`)** | **Claude Code** + **Local LLM** (`zomp` strictly local) | `llamacpp/local` (`127.0.0.1:11500/v1`) via `zomp`, `zdots-ask`, `ai-query` | Employer-sanctioned Claude Code / `$ZDOTS_WORK_AI_GATEWAY_URL` only. Personal consumer lanes (`--hybrid`, `--or`, `import-keychain`) are hard-blocked. |
| **Home** | **Oh-My-Pi (`zomp --hybrid`)** + **Local LLM** | `smol` role (`llamacpp/local`) handles commit messages, titles, and prewalk at $0 | Multi-account pool via `omp-gateway-ctl` (Gemini CLI, Codex, Copilot, OpenRouter, HF) with automatic `429` fallback. |

## 3. Multi-Account Loopback Broker & Gateway (`omp-gateway-ctl`)

`omp` includes a built-in SQLite credential vault (`omp auth-broker`) and an
OpenAI-compatible `/v1/chat/completions` router (`omp auth-gateway`) that load-balances
across multiple OAuth logins and API keys per provider (`google-gemini-cli`,
`openai-codex`, `github-copilot`, `openrouter`, `huggingface`, `llama.cpp`).

Manage the local loopback gateway (`127.0.0.1:11509` broker / `127.0.0.1:11510` gateway)
via `omp-gateway-ctl`:

```bash
omp-gateway-ctl status [--json]      # Check broker (11509) & gateway (11510) health
omp-gateway-ctl login [provider]     # Add an OAuth/API account to the active profile broker
omp-gateway-ctl import-keychain      # Sync Keychain keys into the Home broker (Home-only)
omp-gateway-ctl start                # Start loopback broker + OpenAI gateway on 127.0.0.1:11510
omp-gateway-ctl stop                 # Stop loopback broker + gateway
omp-gateway-ctl check [--strict]     # Probe account health and quota across all accounts
omp-gateway-ctl accounts             # Show provider usage limits across authenticated accounts
```

## 4. What Each AI Agent Needs to Enable Integration

| Agent | Integration Surface | Required Setup |
|---|---|---|
| **Oh-My-Pi (`omp` / `zomp`)** | Primary Home orchestrator + Work local runner | Global `rtk.ts` (`~/.omp/agent/extensions/rtk.ts`, auto-linked into `zomp` profiles); reads `AGENTS.md`, `.agents/skills/`, `graphify-out/`, `groma/`, `backlog/`. |
| **Claude Code (`claude`)** | Primary Work coding agent | Global `rtk hook claude` + `@RTK.md` in `~/.claude/`; reads `CLAUDE.md`/`AGENTS.md` and `.agents/skills/`. Transfer sessions to OMP via `omp --from-claude`. |
| **Gemini CLI (`gm` / `gemini-invoke`)** | Google Gemini + MCP (`ctx-mcp`, `llama-mcp`) | Global `rtk hook gemini` in `~/.gemini/hooks/`; reads `GEMINI.md` / `AGENTS.md` and `graphify query`. At Home, sync `google-gemini-cli` (or `GEMINI_API_KEY`) into `omp-gateway-ctl`. (Do not use `antigravity-cli` in `omp` — Google cancelled third-party Antigravity OAuth access; use `agy` directly for Antigravity.) |
| **Codex CLI (`codex`)** | OpenAI Codex terminal agent | Global `rtk hook codex` in `~/.codex/hooks.json` + `@RTK.md`; reads `AGENTS.md` and `.agents/skills/`. Transfer sessions to OMP via `omp --from-codex`. |
| **Local LLM (`llama.cpp`)** | Always-on loopback inference (`127.0.0.1:11500/v1`) | Managed via `llama-ctl start`; serves `zdots-ask`, `ai-query`, `zaider`, `zpi`, and OMP's `smol` role (`llamacpp/local`) in both Home and Work contexts. |

## 5. Work-Machine Investigation Checklist (Claude Code + Local LLM + OMP)

When evaluating `zomp` on a `ZDOTS_CONTEXT=work` machine alongside Claude Code:

1. **Pull latest `adots` & `zdots`**: `adots-git pull && git -C ~/.config/zsh pull` (ensures `OMP.md`, `providers/tools/omp.zsh`, `bin/omp-gateway-ctl`, and `docs/agents/ai-surface.md` are present).
2. **Install runtime dependencies**: `brew bundle --file ~/.config/zsh/Brewfile.common` (or `npm install -g @oh-my-pi/pi-coding-agent` + `mise install bun@1.4.4`).
3. **Verify work boundary enforcement**: Confirm `zomp --hybrid` and `omp-gateway-ctl import-keychain` refuse to run when `ZDOTS_CONTEXT=work`.
4. **Test strictly-local `zomp`**: With `llama-ctl start`, run `zomp -p "ping"` (`--offline --no-judge --no-spotlight` on `127.0.0.1:11500/v1`).
5. **Evaluate corporate gateway options (if available)**: Check whether employer provides an internal gateway (`ZDOTS_WORK_AI_GATEWAY_URL`, `NODE_EXTRA_CA_CERTS`, `CLAUDE_CODE_USE_FOUNDRY` / `ANTHROPIC_BASE_URL`) compatible with `zomp --work-gateway`, and test `zomp --from-claude` for importing Claude Code sessions into local OMP.

## 6. Home vs. Work Isolation Rules

- **Profile Isolation**: `zomp` isolates credentials and sessions per lane under
  `${XDG_STATE_HOME}/omp/profiles/zdots-{local,hybrid,or,work-gateway}`.
- **Work Machine Hard Boundary (`ZDOTS_CONTEXT=work`)**: `zdots_cloud_lane_guard`
  refuses `--hybrid`, `--or`, and `omp-gateway-ctl import-keychain`. Never import
  personal consumer accounts onto a work machine.
- **No AI Attribution**: Never add `Co-Authored-By:` or AI attribution lines to
  commits, PRs, code, or documentation.
