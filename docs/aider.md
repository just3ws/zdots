# Aider — Local AI Pair Programming

Aider is a terminal-based AI pair programming tool wired to the local llama.cpp server. It provides repo-aware, interactive code editing from the shell — complementing Claude Code for tasks that don't need deep reasoning or large context windows.

## Orientation

```sh
zaider                     # launch in current repo (auto-commits off)
zaider path/to/file.rb     # open with a specific file already in context
zaider --message "..."     # one-shot non-interactive edit
zdots-status               # confirm llama.cpp is UP before starting
```

## How it connects

`providers/ai/aider.zsh` sets the following env vars on every `zaider` call:

| Variable | Value | Notes |
|---|---|---|
| `AIDER_OPENAI_API_BASE` | `$ZDOTS_AI_ENDPOINT/v1` | Derived from active llama.cpp provider |
| `AIDER_OPENAI_API_KEY` | `local` | Ignored by llama.cpp; must be non-empty |
| `AIDER_MODEL` | `openai/local` | `openai/` prefix = OpenAI-compatible endpoint |
| `AIDER_AUTO_COMMITS` | `false` | Review diffs before committing |
| `AIDER_MAX_CHAT_HISTORY_TOKENS` | `8000` | Tight context for 7B model |
| `AIDER_SHOW_MODEL_WARNINGS` | `false` | Suppresses unknown-model registry warning |

The endpoint is always consistent with `$ZDOTS_AI_ENDPOINT` — change the llama.cpp server address in one place and both `ai-query` and `zaider` update automatically.

## Sourcing the provider

`providers/ai/aider.zsh` is not part of the `ZDOTS_SERVICE_AI` provider chain — it's a side-car that layers on top of the existing llama.cpp provider. Source it in your shell by adding to `conf.d/95-ai.zsh` or `.zshrc.local`:

```sh
source "$ZDOTDIR/providers/ai/aider.zsh"
```

The `zaider` function defined there is available immediately after sourcing.

## Capability boundaries

The active model (Qwen2.5-Coder-7B Q4_K_M) is capable but bounded. Match the task to the model:

**Works well:**
- Single-file edits with a clear, specific instruction
- Writing a new function or class from a description
- Explaining what a piece of code does
- Generating tests for an existing function
- Targeted refactors within one file
- Commit message drafting

**Unreliable:**
- Multi-file coordinated changes (context window + instruction-following)
- Complex architectural decisions
- Long autonomous agentic loops (test → fix → rerun)
- Anything requiring deep knowledge of external APIs not in training data

For multi-file or high-reasoning work, use Claude Code. Aider with a local model is the right tool for focused, scoped edits where you don't need the master electrician.

## Aider modes

```sh
zaider                     # default: chat mode, manual file adds
zaider file.rb             # pre-load a file into context
zaider --architect         # architect mode: plan with one model, edit with another
                           # (both use "local" here — useful if you later add a
                           #  reasoning profile to etc/ai-models.yaml)
zaider --watch             # watch mode: aider monitors for AI comments in files
```

## Architect mode + reasoning profile

If you switch to the `reasoning` profile (Qwen2.5-7B-Instruct), you can run architect mode with two distinct models:

```sh
ZDOTS_AI_PROFILE=reasoning llama-ctl install   # switch server to reasoning model
zaider --architect --model openai/local --editor-model openai/local
```

Switch back: `ZDOTS_AI_PROFILE=standard llama-ctl install`

## Updating

Aider is managed by `uv tool`. Update with:

```sh
uv tool upgrade aider-chat
```

Check version: `aider --version`

## Why not OpenCode?

OpenCode has documented tool-calling compatibility issues with Qwen2.5 models (empty `tool_calls` arrays cause hangs). As of 2026-04-20 this is an open issue. Revisit when fixed.

Pi (`badlogic/pi-mono`) is an alternative with no reported local model issues, but is less mature. Aider is the established choice with the deepest local model integration surface.

## See also

- `bin/llama-ctl` — model profile switching
- `bin/llama-caps` — full capability report for the local server
- `docs/llama-cpp.md` — server configuration reference
- `providers/ai/llama-cpp.zsh` — llama.cpp provider (sets `ZDOTS_AI_ENDPOINT`)
