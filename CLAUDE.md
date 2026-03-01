# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal zsh dotfiles repo (`just3ws/zdots`). Manages shell configuration, functions, aliases, and utility tooling for a macOS development environment. The owner is a Ruby developer — `bundle exec` and Rails commands are core daily tools, not optimization targets.

## Running Checks

```shell
zsh -n .zshenv .zprofile .zshrc .aliasrc .fzf.zsh functions/enabled/*
zsh -i -c exit
bin/check
```

## Architecture

### Shell Startup Chain

```
~/.zshenv (symlinked to $ZDOTDIR/.zshenv)
  → sets XDG paths, core env vars, PATH, HISTFILE
  → cheap Homebrew prefix detection only
  → sets minimal fpath for autoload compatibility

~/.config/zsh/.zshrc
  → p10k instant prompt (must stay at top)
  → sources modular config in conf.d/*.zsh
  → prompt + env + lazy asdf + options + key bindings + integrations
```

### Function Autoloading

Functions live in `functions/enabled/` and are autoloaded via a glob loop in `conf.d/40-completion.zsh`:
```zsh
for fn in $ZDOTDIR/functions/enabled/*(.x); do
  autoload -Uz "$(basename $fn)"
done
```

Files must be executable (`chmod +x`). Each file defines a single function matching its filename.

### Key Files

| File | Purpose |
|------|---------|
| `.zshenv` | Environment, PATH, minimal fpath bootstrap |
| `.zshrc` | Thin loader for modular config |
| `conf.d/*.zsh` | Ordered interactive shell modules |
| `.aliasrc` | All aliases (directory hashes, git, ruby, utilities) |
| `Brewfile` | Homebrew dependencies for this config |
| `fzfrc` | FZF configuration (Dracula theme, ag backend) |
| `.p10k.zsh` | Powerlevel10k theme (wizard-generated, ~90KB) |
| `functions/enabled/upgrade` | Master upgrade orchestrator (homebrew → asdf) |
| `bin/bootstrap` | First-time setup script |
| `bin/check` | Local validation script |

### Conventions

- Functions: lowercase, hyphen-separated (`upgrade-homebrew`, `cleanup-homebrew`)
- Environment vars: `UPPER_SNAKE_CASE`
- File headers: `# vim:ft=zsh` or `#!/usr/bin/env zsh`
- XDG Base Directory compliance throughout
- Editor is always neovim (`$EDITOR`); `vim` and `vi` are aliased to it
- `klear` is the scrollback-clearing function — used as a prefix before running visible output commands (e.g., `klear ; ruby script.rb`). It is a helper, not an optimization target.
- GNU coreutils preferred: `gls`, `gdate` (with graceful BSD fallback aliases)
- `clobber` is unset — use `>!` to overwrite files

### Deprecation Policy

- A helper/function can be removed when all are true:
  - No history usage in recent snapshots.
  - Backing path/config no longer exists.
  - No remaining internal references/docs depend on it.
- Removals should be done in a dedicated commit with docs updated in the same PR.
