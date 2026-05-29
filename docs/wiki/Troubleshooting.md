# Troubleshooting

## AI up, intelligence down

Symptoms:

- `zdots-ctl status` shows AI server up
- intelligence/Postgres down
- `capabilities --json` may still show `health_errors: 0`

Meaning: local inference is available, but the knowledge layer is not connected.

Next checks:

```sh
zdots-ctx status
zdots-ctl check
agent-guide --json
```

If a command contradicts its `--help` or manpage, file `zdots-issue`.
