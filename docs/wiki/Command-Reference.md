# Command Reference

Canonical command contracts live in `man/` and `docs/generated/interface-inventory.json`.

## Orientation

| Command | Purpose |
|---|---|
| `zmorning --brief` | Daily session brief |
| `zdots-status --once` | Status panel snapshot |
| `agent-guide` | Agent service guide |
| `capabilities --json` | Machine-readable environment contract |

## Platform

| Command | Purpose |
|---|---|
| `zdots-ctl status` | Live aggregate service status |
| `zdots-ctl check` | Deep diagnostic |
| `zdots-ctl up` | Start platform services |
| `zdots-ctl down` | Stop platform services |

## Knowledge

| Command | Purpose |
|---|---|
| `zdots-ctx status` | Postgres brain health |
| `zdots-ctx query <term>` | Search methodology and lessons |
| `zdots-ctx hydrate [tag]` | Emit AI-ready context |
| `zdots-ctx capture` | Distill session residue when capture is enabled |

## AI

| Command | Purpose |
|---|---|
| `ai-query` | Guarded local inference |
| `zdots-ask` | Domain-aware prompt router |
| `llama-ctl` | Local llama.cpp lifecycle |

Known gaps are listed in `docs/generated/docs-contract-known-gaps.txt`.
