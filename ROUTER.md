# `zai` router

`zai` is the local-first dispatcher for `zdots-ask`, Pi, and Aider. It never
changes engines automatically. The default is local inference; cloud tools
remain separate, explicit commands with their own boundary checks.

| Flag | Route | Use |
|---|---|---|
| `--local` | `zdots-ask` | Local inference; default |
| `--pi` | `zpi` | Read, explore, explain, and plan |
| `--aider` | `zaider` | Edit and patch with local llama.cpp |
| `--dry-run` | no inference | Print the selected route |

The implementation is [providers/tools/router.zsh](providers/tools/router.zsh).
The offline contract is covered by [tests/zai_router.bats](tests/zai_router.bats).
