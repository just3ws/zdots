---
id: deploy-log-analysis
title: "Deploy Log Analysis"
purpose: Use phase-marked bootstrap/update/upgrade logs for local AI and human diagnostics.
---

# Deploy Log Analysis

`bootstrap`, `zdots-update-local`, and `upgrade-homebrew` write two files per run:

| File | Use |
|---|---|
| `*.summary.md` | First-pass handoff for Pi or human review |
| `*.log` | Full command transcript when the summary is not enough |

Default location:

```bash
${XDG_STATE_HOME:-$HOME/.local/state}/zsh
```

Override per run:

```bash
ZDOTS_LOG_DIR=/tmp/zdots-logs bin/zdots-update-local
```

## Helper

Use `zdots-log-analyze` to package the right context, prompt, summary, and log tail:

```bash
zdots-log-analyze update
zdots-log-analyze bootstrap --tail 400
zdots-log-analyze upgrade --ai
zdots-log-analyze update --list
zdots-ctx diagnose-log update --tail 160
```

The diagnostic pack includes a non-OTel system snapshot by default:

- host and kernel
- repo commit
- `ZDOTS_CONTEXT`, `ZDOTS_ENV_PROFILE`, `ZDOTS_AI_MODE`
- selected AI endpoints
- selected Brew bundle file
- disk space
- required command availability
- chat/embed endpoint reachability

This snapshot is deliberately independent of OpenTelemetry so it still works
when the collector, LGTM stack, or local service telemetry is down.

For constrained Pi workflows, paste or pipe the generated diagnostic pack:

```bash
zdots-log-analyze update --tail 160 | zpi
```

For direct local inference:

```bash
zdots-log-analyze update --ai
```

To omit the snapshot:

```bash
zdots-log-analyze update --no-snapshot
```

## Analysis Order

1. Read `*.summary.md`.
2. Identify the failed or suspicious phase.
3. Read only the relevant tail of `*.log`.
4. Separate hard failures from warnings and skipped optional steps.
5. Run one non-destructive verification command.
6. If shared zdots infrastructure is broken, file or update a `zdots-issue`.

## Prompt Contract

The helper tells the model:

- This is zdots deploy/update/bootstrap output.
- The host may be remote and constrained.
- Local Pi/llama.cpp may be the only available model.
- Cloud upload and raw sensitive-data sharing are not acceptable defaults.
- Brewfile selection is context-driven: `home` uses `Brewfile.home`, `work` uses `Brewfile.work`.
- Logs are phase-marked; summary first, transcript second.
- Infrastructure breakage needs operator coordination.

This keeps small local models focused on diagnostics instead of generic shell advice.
