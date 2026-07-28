---
name: cc-audit
description: Audit and harden Claude Code's configuration on a PHI/work zdots machine — the layer cc-doctor doesn't cover. Checks global plugins for cloud egress, verifies telemetry points at the LOCAL collector, and scopes cloud-touching plugins/MCP to the one project that needs them. Use for "audit claude code config", "is Claude Code leaking", "cc plugin audit", "scope a plugin", or after installing CC plugins on a PHI-adjacent machine.
---

# /cc-audit — Claude Code config hygiene (PHI machine)

`cc-doctor` validates the **tracked** zdots CC surface (settings.json, .mcp.json,
hooks, deny-list). It does **not** see the **global** plugin layer
(`~/.claude/`), where cloud-egress risk lives on a PHI machine. This skill audits
that gap and remediates per project, never globally.

**Context first:** this only matters when `ZDOTS_CONTEXT=work` (PHI-adjacent,
local-only AI). On `home`, cloud plugins/telemetry are allowed — note and move on.

**Rules:**
- Cloud egress on a work machine is the threat. Loopback (127.0.0.1 / RFC-1918) is fine.
- Remediate by **scoping**, not deleting: move a cloud plugin to the project that
  needs it (`settings.local.json` `enabledPlugins`), disable it globally.
- `~/.claude/**` is yours, not zdots/adots — edit freely, but never push, and
  never enable a cloud plugin globally on work.
- Report; apply only the obvious scoping. Anything ambiguous → ask the operator.

---

## Gate 0 — Tracked baseline

```bash
cc-doctor    # must be green; fix tracked-config failures here before continuing
```

## Gate 1 — Global plugins: cloud egress

```bash
# Enabled plugins (global) + their marketplaces
jq -r '.enabledPlugins | to_entries[] | "\(.value)\t\(.key)"' ~/.claude/settings.json
jq -r '.plugins | keys[]' ~/.claude/plugins/installed_plugins.json 2>/dev/null
# Which MCP servers want cloud auth (a cloud-egress tell)?
jq -r 'keys[]' ~/.claude/mcp-needs-auth-cache.json 2>/dev/null
```

Classify each enabled plugin:

| Egress | Examples | Verdict on work |
|--------|----------|-----------------|
| local only | lsp servers, ponytail, frontend-design, duckdb-skills* | keep |
| `gh`/CLI authed, narrow scope | sentry-cli (`org:ci`) | keep (note the token scope) |
| **cloud MCP / telemetry** | sentry (mcp.sentry.dev), dash0 (dash0.com), any `claude.ai_*` | **scope or remove** |

\* duckdb `s3-explore`/`spatial` can reach S3 — fine unless used on PHI data.

**Tell for "armed but inert":** a plugin whose hooks fire every event
(SessionStart/UserPromptSubmit/Stop) but no-op until a config file exists is one
file away from egress — treat as active. (This is what the Dash0 plugin was.)

## Gate 2 — Telemetry points at the LOCAL collector

```bash
jq -r '.env | "enable=\(.CLAUDE_CODE_ENABLE_TELEMETRY) proto=\(.OTEL_EXPORTER_OTLP_PROTOCOL) endpoint=\(.OTEL_EXPORTER_OTLP_ENDPOINT)"' "$ZDOTDIR/.claude/settings.json"
# Endpoint MUST be loopback. Collector must be listening:
lsof -nP -iTCP:4317 -sTCP:LISTEN >/dev/null && echo "OTLP/gRPC 4317: up" || echo "collector DOWN — zsvc start otel"
```

PASS: `endpoint=http://127.0.0.1:4317` (gRPC) or `:4318` (http), no
`OTEL_EXPORTER_OTLP_HEADERS` auth token, collector listening. CC exports
metrics/logs/traces — **not** raw tool I/O — so loopback export stays within §10.

If telemetry isn't wired and the operator wants it: add the `env` block to the
**tracked** `$ZDOTDIR/.claude/settings.json` (shared default — the otel stack runs
at the same loopback endpoint on every zdots machine), commit, and tell the user
to **quit + relaunch** Claude Code (env is read only at startup).

```json
"env": {
  "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
  "OTEL_METRICS_EXPORTER": "otlp",
  "OTEL_LOGS_EXPORTER": "otlp",
  "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
  "OTEL_EXPORTER_OTLP_ENDPOINT": "http://127.0.0.1:4317"
}
```

## Gate 3 — Scope cloud plugins to the project that needs them

For each cloud plugin a project legitimately uses (e.g. Sentry for the tenant app repo):

```bash
# 1. disable globally
#    ~/.claude/settings.json → "enabledPlugins": { "<plugin>@<mkt>": false }
# 2. enable only in that project's MACHINE-LOCAL settings (gitignored if possible;
#    if the project tracks settings.local.json, the commit is the user's call)
#    <project>/.claude/settings.local.json → "enabledPlugins": { "<plugin>@<mkt>": true }
```

Fully remove a plugin with no owning project:

```bash
claude plugin uninstall <plugin>@<marketplace>
# orphaned cache/data dirs are NOT pruned automatically:
rm -rf ~/.claude/plugins/cache/<marketplace>/<plugin> ~/.claude/plugins/data/<plugin>-<marketplace>
find ~/.claude/plugins -iname '*<plugin>*'   # expect 0
```

Changes to `enabledPlugins` take effect on the **next CC launch**.

## Report

- Tracked baseline (cc-doctor): N ok / N warn / N fail.
- Cloud-egress plugins found: which, and disposition (kept/scoped/removed).
- Telemetry: local + collector up? or action taken.
- Anything ambiguous left for the operator.

**Automatic baseline:** `cc-doctor`'s "Global plugins & telemetry" section now
flags cloud-egress plugins enabled globally on `context=work` and FAILs on
non-loopback telemetry — so `cc-doctor` catches drift between runs of this skill.
This skill is the deeper, remediating pass (scoping, removal, setup).
