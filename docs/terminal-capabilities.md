---
id: terminal-capabilities
title: "Terminal Capability Discovery"
purpose: Documents how Zdots detects and adapts to terminal capabilities at startup.
links:
  - id: architecture
    rel: related
  - id: readme
    rel: parent
---

# Terminal Capability Discovery

How Zdots detects and adapts to terminal capabilities.

## Detection Hierarchy

Three levels of detection, from broadest to most specific:

### 1. Interactive Mode: `[[ -o interactive ]]`

Tests whether the shell is running interactively (connected to a user). Used to guard features that only make sense in interactive sessions: prompts, aliases, completion.

**When to use:** Guarding any feature that should not run in scripts or `zsh -c` batch execution.

### 2. ZLE Availability: `[[ -o zle ]]`

Tests whether the Zsh Line Editor is active. ZLE provides widgets, key bindings, and the editing interface. A shell can be interactive without ZLE (e.g., `zsh -i -c 'command'` subshells in CI).

**When to use:** Guarding `bindkey`, `zle -N`, widget registration, and any code that manipulates the line editor. Always combine with interactive check: `[[ -o interactive && -o zle ]]`.

### 3. TTY File Descriptors: `[[ -t N ]]`

Tests whether a specific file descriptor is connected to a terminal device:
- `-t 0`: stdin is a TTY (user can type)
- `-t 1`: stdout is a TTY (output goes to screen)
- `-t 2`: stderr is a TTY (errors go to screen)

**When to use:** Guarding output formatting (colors, escape sequences). iTerm2 shell integration uses `-t 1` to avoid injecting OSC sequences when stdout is piped.

## Guard Patterns in Zdots

| Pattern | Where Used | Purpose |
|---------|-----------|---------|
| `[[ -o interactive ]]` | conf.d modules, providers | Universal interactive guard |
| `[[ -o interactive && -o zle ]]` | conf.d/60-bindings.zsh, conf.d/74-fzf.zsh, conf.d/76-history-widgets.zsh | Widget and key binding operations |
| `[[ -t 1 ]]` | conf.d/73-zsh-plugins.zsh (iTerm2) | TTY output guard |
| `[[ ! -t 0 ]]` | conf.d/72-ai-function.zsh (ai function) | Detect piped stdin |

## Multiplexer Detection

Terminal multiplexers (tmux, screen) alter terminal behavior. Zdots detects them via:
- `$TMUX` environment variable (set inside tmux)
- `$TERM` prefix: `tmux-*` or `screen*`

## Capability Reporting

Run `bin/capabilities` to see current terminal state. The "Terminal State" section reports all detection results for the current session.

## Adding New Guards

When writing new conf.d modules or providers:
1. **Default to `[[ -o interactive ]]`** for features that need a user present
2. **Add `&& -o zle`** if the code uses `bindkey`, `zle`, or widget operations
3. **Add `-t 1`** if the code emits escape sequences or formatting
4. **Test in CI:** Run `bin/check` which exercises non-ZLE subshells
