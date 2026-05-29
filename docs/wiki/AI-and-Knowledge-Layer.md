# AI and Knowledge Layer

Primary commands:

- `ai-query`
- `zdots-ask`
- `zdots-ctx query`
- `zdots-ctx hydrate`
- `llama-ctl`

The default posture is local AI. `ZDOTS_AI_MODE=local` requires a loopback or RFC-1918 endpoint. Use `ZDOTS_AI_MODE=none` when inference must be disabled.

`zdots-ctx` writes through the app interface. Use `psql -U zdots_ro my` for read-only exploration.
