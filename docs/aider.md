# Aider — Local AI Pair Programming

Aider is a terminal-based AI pair programming tool wired to the local llama.cpp server. It provides repo-aware, interactive code editing from the shell — complementing Claude Code for tasks that don't need deep reasoning or large context windows.

## Orientation

```sh
zaider                     # launch in current repo (architect mode enabled)
laid                       # "Low-load Aider" — runs with lower CPU priority
zaider path/to/file.rb     # open with a specific file already in context
zaider --message "..."     # one-shot non-interactive edit
zdots-status               # confirm llama.cpp is UP before starting
```

## How it connects

`providers/ai/aider.zsh` sets the following env vars on every `zaider` call:

| Variable | Value | Notes |
|---|---|---|
| `AIDER_OPENAI_API_BASE` | `$ZDOTS_AI_ENDPOINT/v1` | Derived from active llama.cpp provider |
| `AIDER_OPENAI_API_KEY` | `local` | Ignored by llama.cpp; any value works |
| `AIDER_MODEL` | `openai/local` | `openai/` prefix = OpenAI-compatible endpoint |
| `AIDER_AUTO_COMMITS` | `false` | Review plans/diffs before committing |
| `AIDER_CONFIG` | `$ZDOTDIR/.aider.conf.yml` | Shared config for all repos |

## Load Management: `laid` vs `zaider`

Running a 7B model locally on a dev machine can cause UI stutter. We provide two ways to manage this:

*   **`zaider`**: Standard execution. Use this when you want maximum speed and aren't doing heavy work elsewhere.
*   **`laid` (Low-load Aider)**: Runs with `nice -n 19` and limits internal mapping to 2 threads. Use this when your IDE, browser, or build commands are the priority.

## Capability boundaries (May 2026 SOTA)

The active model (**Qwen3-Coder-7B Q4_K_M**) is a frontier-level coding model for its size.

**Works well:**
- **Architect Mode**: It can plan its own multi-file edits and self-correct.
- Single-file and scoped multi-file edits.
- Complex refactors where "thinking" is required.
- Generating tests and documentation.

**Edit Format:**
We default to **`edit-format: architect`** in `.aider.conf.yml`. This leverages the model's reasoning capabilities to plan changes before applying them, which is significantly more reliable for local 7B models than pure diff-based editing.

## Repo Mapping with Nomic v2

We use **Nomic Embed Text v2 (MoE)** for the repository map. This model is significantly better at semantic retrieval than v1.5, allowing Aider to find relevant context in your repo even with a tight 2048-token map limit.

## See also

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

## RTK integration

**Short answer: RTK and aider have no direct integration point.**

RTK (`cmd | rtk | LLM`) operates at the CLI stdout layer — it preprocesses text before it enters an LLM context window. Aider manages its own context pipeline internally: it reads files via `/add`, builds the repo map, maintains chat history, and sends everything to the model in one structured request. There is no stdin hook or plugin interface to inject RTK into that pipeline.

**What doesn't work:**
```sh
rtk zaider   # ❌ RTK wraps the entire aider process — output is aider's TUI, not inference content
```

**What does work — adjacent workflows:**

```sh
# Understand a large file before deciding to /add it
rtk read path/to/big-file.rb     # compressed view → decide if it's worth adding

# Compressed git log before drafting a commit message in aider
rtk git log --oneline -20        # read the output, then open zaider

# Summarize a noisy error log before pasting it into aider's chat
cat error.log | rtk | pbcopy    # compressed → paste into aider with /add or inline

# Pipeline: use rtk with ai-query instead of aider for analysis-only tasks
git diff | rtk | ai-query "Write a commit message"
```

**Rule of thumb:** Use RTK + `ai-query` for analysis pipelines. Use `zaider` for interactive editing sessions where you control what enters context with `/add` and `/drop`.

## See also

- `bin/llama-ctl` — model profile switching
- `bin/llama-caps` — full capability report for the local server
- `docs/llama-cpp.md` — server configuration reference
- `providers/ai/llama-cpp.zsh` — llama.cpp provider (sets `ZDOTS_AI_ENDPOINT`)
