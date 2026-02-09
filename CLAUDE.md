# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal zsh dotfiles repo (`just3ws/zdots`). Manages shell configuration, functions, aliases, and workspace tooling for a macOS development environment. The owner is a Ruby developer — `bundle exec` and Rails commands are core daily tools, not optimization targets.

## Running Tests

```shell
bin/test-wsp          # Test wsp workspace helper (no .zshenv modification)
bin/test-wsp-env      # Test wsp workspace helper (with .zshenv export)
```

Both use `set -euo pipefail`, print "ok" on success, and clean up via `trap EXIT`. They validate that `wsp init` creates the expected directory, RC file, function wrapper, and (optionally) environment export.

## Architecture

### Shell Startup Chain

```
~/.zshenv (symlinked to $ZDOTDIR/.zshenv)
  → sets XDG paths, EDITOR, PATH, HISTFILE
  → autoloads functions from functions/enabled/
  → sets fpath and path arrays

~/.config/zsh/.zshrc
  → p10k instant prompt (must stay at top)
  → .antigenrc (oh-my-zsh + powerlevel10k)
  → setopt/unsetopt blocks
  → key bindings
  → sources: .aliasrc, .iterm2_shell_integration.zsh, .fzf.zsh, .p10k.zsh
```

### Function Autoloading

Functions live in `functions/enabled/` and are autoloaded via a glob loop in `.zshenv`:
```zsh
for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done
```

Files must be executable (`chmod +x`). Each file defines a single function matching its filename.

### Workspace System (`wsp`)

`wsp` is a generic workspace management framework. It creates project workspace helpers that manage:
- A root directory (`NAMEPATH` env var)
- An RC file listing repos (`.namerc`, one repo per line, `#` for comments)
- A history log at `~/.local/share/name-all-do/history`
- A generated function wrapper in `functions/enabled/`

**Creating a new workspace:** `wsp init <name> <path>` generates the function file, RC file, and appends the path export to `.zshenv` (skip with `WSP_NO_ENV=1`).

**Workspace actions:** `cd` (default), `rc` (print RC), `all-do` (run command across all repos listed in RC file).

Concrete implementations: `omf`, `w3r` — each delegates to `wsp` with its own paths.

### Key Files

| File | Purpose |
|------|---------|
| `.zshenv` | Environment, PATH, function autoloading |
| `.zshrc` | Shell options, plugins, key bindings, sourcing |
| `.aliasrc` | All aliases (directory hashes, git, ruby, utilities) |
| `.antigenrc` | Plugin manager config (oh-my-zsh + p10k) |
| `fzfrc` | FZF configuration (Dracula theme, ag backend) |
| `.p10k.zsh` | Powerlevel10k theme (wizard-generated, ~90KB) |
| `functions/enabled/upgrade` | Master upgrade orchestrator (homebrew → asdf → antigen) |
| `functions/enabled/wsp` | Workspace framework |

### Conventions

- Functions: lowercase, hyphen-separated (`upgrade-homebrew`, `omf-all-do`)
- Environment vars: `UPPER_SNAKE_CASE`
- RC files: `.{name}rc` in workspace root
- File headers: `# vim:ft=zsh` or `#!/usr/bin/env zsh`
- XDG Base Directory compliance throughout
- Editor is always neovim (`$EDITOR`); `vim` and `vi` are aliased to it
- `klear` is the scrollback-clearing function — used as a prefix before running visible output commands (e.g., `klear ; ruby script.rb`). It is a helper, not an optimization target.
- GNU coreutils preferred: `gls`, `gdate` (via Homebrew)
- `clobber` is unset — use `>!` to overwrite files
