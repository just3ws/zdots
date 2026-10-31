---
name: zdots-aider
scope: zdots repository
audience: Aider
inherits: AGENTS.md
---

# Aider

Repository-wide policy is in [AGENTS.md](AGENTS.md). This file contains only
Aider-specific operation.

- `zaider`: local llama.cpp coding session. `laid`: low-priority background run.
- `zaider --hf`: explicit cloud lane. Home-only, requires `phi_scrub` and
  `HF_TOKEN` from Keychain. Interactive prompts are not scrubbed; never include
  PHI, secrets, or credentials.
- Pi is for exploration and planning; use Aider or a reviewed manual patch for
  edits. Review all changes before committing; automatic commits are disabled.
- Keep the local 7B model's context deliberate: `/add` only needed files,
  `/drop` them when done, `/clear` between tasks, `/tokens` before large files.
- `zdots_aider_init` exports peer capability counts for Aider's shell without
  adding them to the model prompt.

See [docs/llama-cpp.md](docs/llama-cpp.md) for the local inference contract and
[docs/tooling.md](docs/tooling.md) for platform commands.
