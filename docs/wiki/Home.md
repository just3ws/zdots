# Zdots Wiki

This directory is the versioned source for the public wiki. GitHub wiki pages may mirror these files, but this repo is authoritative.

## Start Here

- [Command Reference](Command-Reference.md)
- [System Map](System-Map.md)
- [Daily Operations](Daily-Operations.md)
- [AI and Knowledge Layer](AI-and-Knowledge-Layer.md)
- [Observability](Observability.md)
- [PHI Safety](PHI-Safety.md)
- [Troubleshooting](Troubleshooting.md)

## The ecosystem

Zdots is the shell platform in a four-part personal-OS ecosystem. Peers:

| System | Role | Wiki |
|---|---|---|
| **adots** | Home dotfiles + agent coordination (bare repo at `~/.homegit`) | [adots wiki](https://github.com/just3ws/adots/wiki) |
| **vdots** | Neovim platform — LSP, plugins, editor config | [vdots wiki](https://github.com/just3ws/vdots/wiki) |
| **my** | Private "Cerebral Control Plane" (no public wiki) | [My-System](https://github.com/just3ws/adots/wiki/My-System) |

## Truth Sources

- Live state: `zdots-ctl status --json`
- Environment contract: `capabilities --json`
- Agent guide: `agent-guide --json`
- Interface inventory: `docs/generated/interface-inventory.json`
- Manpages: `man/`
- Policy: `AGENTS.md`
