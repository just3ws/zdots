# zdots Tenant CLI SDK (`lib/sdk/`)

External tenants (starting with `zdots-work` / `work-*`) consume `zdots` through two stable, versioned seams introduced in [ADR-0005](adr/0005-tiered-cli-surface-and-tenant-contract.md):

1. **Service Discovery (`capabilities --json` → `service_surface`, `zdots.surface.v1`):**
   - Query `capabilities --json | jq '.service_surface'` to inspect `inference`, `embeddings`, `jaeger`, `knowledge`, `warehouse`, and `colima`.
   - Every service reports a standardized `status` (`ready` | `stopped` | `disabled`) and `reason` (`ZDOTS_AI_MODE=none`, `healthcheck_failed`, `disconnected`, `runtime_stopped`, etc.) so consumers degrade cleanly without probing `PATH` or scraping stderr.
2. **Sourceable Shell Helpers (`$ZDOTDIR/lib/sdk/`):**

| Library | Functions | Purpose |
|---|---|---|
| `lib/sdk/cli-help.bash` | `zdots_cli_wants_help`, `zdots_cli_wants_help_strict`, `zdots_sdk_help_from_header` | Short-circuit `-h`/`--help` before side effects and render header doc-comments. |
| `lib/sdk/cli-audit.bash` | `zdots_audit_init <tool> <write_class>` | Emit `START`/`END` NDJSON records (`read-only`, `lake-write`, `db-mutating`) to `$ZDOTS_AUDIT_LOG` with a chained `EXIT` trap. |
| `lib/sdk/docker-host.bash` | `zdots_docker_host`, `zdots_export_docker_host` | Resolve `unix://...` Docker socket via `colima-status socket` without hardcoding `~/.colima`. |

## Example

```bash
#!/usr/bin/env bash
# work-report — Generate daily summary report.
# Usage: work-report [--dry-run] [--help]
set -euo pipefail

ZDOTS="${ZDOTDIR:-$HOME/.config/zsh}"
source "$ZDOTS/lib/sdk/cli-help.bash"
source "$ZDOTS/lib/sdk/cli-audit.bash"
source "$ZDOTS/lib/sdk/docker-host.bash"

zdots_cli_wants_help "$@" && { zdots_sdk_help_from_header "$0"; exit 0; }
zdots_audit_init "work-report" "read-only"
zdots_export_docker_host || true
```
