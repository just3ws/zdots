# Graphify Discovery

_Audit date: 2026-06-07 · target: `~/.config/zsh` (zdots) · host: powerstation (Apple Silicon, macOS)_

## Package identity (vetted on PyPI before install)

| Field | Value |
|---|---|
| pip package | `graphifyy` 0.8.34 |
| CLI | `graphify` |
| License | MIT (safishamsi/graphify) |
| requires_python | `>=3.10` |
| Core deps | `networkx`, `datasketch`, `rapidfuzz`, `tree-sitter` + ~30 language grammars |
| Cloud deps | **none in core** — every LLM SDK (`openai`/`anthropic`/`bedrock`/`gemini`/`ollama`) is an optional `extra` |

**Security verdict:** the base install is fully local/offline — pure static analysis (tree-sitter AST + graph algorithms). No network egress, no API keys required to build or query a graph. LLM is optional and only used to *name* communities (`label`) or for `extract --mode deep` semantic edges. This satisfies the local-first + PHI posture: nothing leaves the machine unless you opt into an LLM backend, and that backend can be the local llama.cpp (`openai` extra → `:11500/v1`).

## Python / runtime strategy

| Aspect | Finding |
|---|---|
| Version manager | **mise** (no pyenv/asdf). `python` pinned `3.14.5` in `mise.toml`. |
| Installers present | `pipx`, `uv` both available |
| Shared "AI venv" | none — `aider` is a `uv` tool (`~/.local/share/uv/tools/aider-chat`) |
| **Pre-existing graphify** | already installed in the mise python (`~/.local/share/mise/installs/python/3.14.5/bin/graphify`, `pip list` shows `graphifyy 0.8.34`) — **drift** |

### Python 3.14 caveat
`graspologic` (the `leiden` community-detection extra) is gated `python_version < "3.13"`, so Leiden clustering is unavailable on 3.14. Graphify falls back to its built-in clustering (419 communities were produced fine). If high-quality Leiden communities are ever wanted, run graphify from a 3.12 venv.

## AI-tool configs located

| Tool | Config surface graphify would touch |
|---|---|
| Claude Code | `CLAUDE.md` + a **PreToolUse hook** (`claude install`) — collides with the existing `cc-hook-guard` chain; design carefully |
| Pi | `~/.pi/agent/skills/graphify/` (`pi install`) — additive, safe |
| Aider | `AGENTS.md` section (`aider install`) — edits a tracked, curated file |
| Codex/OpenCode | `AGENTS.md` |

Shell integration: zdots uses `functions/enabled/_*` completions, `bin/` on PATH, `conf.d/*.zsh` lazy loaders. A `graphify` wrapper/alias + completion would follow that pattern.

## Recommended installation location

**pipx** (chosen). Rationale: isolated per-tool venv, avoids system/mise-python pollution, clean uninstall, matches "avoid system Python." Installed: `~/.local/bin/graphify` (0.8.34), which shadows the drifting mise-python copy on PATH.

**Cleanup recommendation:** remove the stray mise-python install to end the drift —
`~/.local/share/mise/installs/python/3.14.5/bin/pip uninstall -y graphifyy` (or add `graphifyy` to mise default-packages if you'd rather standardize there). pipx remains the source of truth.

## Artifacts produced this audit

- `graphify-out/graph.json` (1.8M), `graph.html` (1.8M), `GRAPH_REPORT.md` (72K), `manifest.json` (89K) — gitignored (`graphify-out/`), regenerate with `graphify update .`.
- This `analysis-assets/graphify/` doc set.
