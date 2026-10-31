---
name: zdots-pi
scope: zdots repository
audience: Pi
inherits: AGENTS.md
---

# Pi

Repository-wide policy is in [AGENTS.md](AGENTS.md). This file contains only
Pi-specific operation.

- `zpi`: local interactive session; `zpi -p` prints a one-shot response.
- `zpi --or`: explicit OpenRouter lane. Set `ZDOTS_OR_MODEL`; the lane is
  home-only, requires `phi_scrub`, and loads its key from Keychain. Interactive
  prompts are not scrubbed; never include PHI, secrets, or credentials.
- Use Pi for exploration, reading, and planning. Make edits through a reviewed
  patch or Aider; do not enable write permissions casually.
- `zpi` disables telemetry, stores sessions under `${XDG_STATE_HOME}/pi`, and
  enforces the configured AI boundary.
- Start a new session for a distinct task. Keep the local model's context
  focused; see [docs/llama-cpp.md](docs/llama-cpp.md).
- `zdots_pi_init` exposes peer capability counts to Pi's shell without adding
  them to the model prompt.

See [docs/tooling.md](docs/tooling.md) for platform commands.
