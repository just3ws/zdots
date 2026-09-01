---
id: openobserve
title: "OpenObserve — native local observability"
purpose: Operate the native OpenObserve backend that stores logs, metrics, and traces locally, replacing the Docker LGTM stack.
links:
  - id: otel-collector-guide
    rel: related
  - id: local-url-routing
    rel: related
  - id: readme
    rel: parent
---

# OpenObserve — native local observability

OpenObserve is a single native binary that stores **logs, metrics, and traces**
and serves its own UI. It replaces the `grafana/otel-lgtm` Docker stack, which
forced a 4 GB Colima VM to run Loki/Tempo/Mimir — horizontal-scale datastores we
never use as a single developer, and the root of recurring memory pressure on the
16 GB box.

The OTel Collector is unchanged as the ingestion front door; OpenObserve is just
the backend it forwards to (replacing the LGTM exporter).

Managed by `bin/openobserve-ctl` and as `zsvc o2`. Migration tracked in backlog
**Z-134** (phased).

## Quick start

```bash
openobserve-ctl install     # pinned binary, sha-verified; provisions Keychain creds; registers launchd
zsvc start o2               # or: openobserve-ctl start
zsvc status o2              # health + pid + endpoint
open http://127.0.0.1:5080  # UI  (or https://o2.localhost)
openobserve-ctl creds --show-password   # login: root@zdots.local
```

## Endpoints

| What | Address |
|---|---|
| UI / OTLP HTTP | `http://127.0.0.1:5080` (OTLP ingest at `/api/default`) |
| OTLP gRPC | `127.0.0.1:5081` |

## Lifecycle (`openobserve-ctl` / `zsvc o2`)

`install · start · stop · restart · reinit · status · health · logs · config · creds`

`install` is idempotent — it skips the (~250 MB) download when the pinned version
is already on disk, then re-provisions creds and the launchd plist. The binary is
**not** committed to the repo; `install` pulls and sha256-verifies it.

## Disposable data & credential sync

Local telemetry is **disposable** — short-lived logs/metrics/traces for one
developer, not a system of record. The design leans into that:

- **Keychain is the single source of truth** for the root credential
  (`zdots / ZDOTS_O2_ROOT_PASSWORD`). Both the UI login and the collector's OTLP
  basic-auth derive from it.

  Retrieve it either way:

  ```bash
  openobserve-ctl creds --show-password                                   # via the ctl
  security find-generic-password -s zdots -a ZDOTS_O2_ROOT_PASSWORD -w      # Keychain direct
  ```

- OpenObserve only reads `ZO_ROOT_USER_PASSWORD` on **first init**, so a password
  set/rotated later won't match the UI. The fix is not to protect the data — it's
  to re-init cleanly:

  ```bash
  openobserve-ctl reinit            # wipe data dir; root re-created from Keychain
  openobserve-ctl reinit --rotate   # also generate a fresh Keychain password first
  ```

  `reinit` guards the path before any `rm -rf`, stops the service, wipes
  `ZO_DATA_DIR`, and restarts. Streams re-populate from the collector within ~15s.
- **Retention** defaults to 3 days on home, 2 days enforced on work
  (`ZDOTS_O2_RETENTION_DAYS` → `ZO_COMPACT_DATA_RETENTION_DAYS`) so the store
  self-trims instead of growing unbounded.

## Volume controls (Z-156)

Retention is a *ceiling*; it does not slow the *ingest rate*. The store once
grew to 17 GB because a derived spanmetrics histogram
(`traces_span_metrics_duration_bucket`) ingested ~2 GB/day — ~60% of the store —
while retention was healthy. Volume is controlled in three layers:

1. **Source** (`etc/otel-collector.yaml`, shared across machines) — the
   spanmetrics connector runs with `exemplars: false` (trace IDs on every
   histogram point were the dominant multiplier) and `metrics_flush_interval:
   60s` (vs 5s — ~12× fewer data points). RED metrics and all latency buckets
   are retained; only waste is removed.
2. **Retention** — `ZDOTS_O2_RETENTION_DAYS`, tighter on work (above).
3. **Drift guard** — `zdots-doctor` warns when the data dir exceeds
   `ZDOTS_O2_SIZE_WARN_GB` (default 8 GB).

When the store grows, diagnose with the `/telemetry-volume` runbook — the cause
is almost always ingest volume from a derived metric, not retention.

## PHI / security posture

This machine is PHI-adjacent; OpenObserve is configured local-only:

- **Loopback bind only** — `ZO_HTTP_ADDR=127.0.0.1` for both `:5080` and `:5081`.
  Verify: `lsof -nP -iTCP -sTCP:LISTEN | grep openobserve` (must show `127.0.0.1`,
  never `0.0.0.0`).
- **Telemetry disabled** — `ZO_TELEMETRY=false`, no usage phone-home.
- **No secret in the plist** — the launchd job runs `openobserve-ctl serve`, an
  internal verb that loads the root password from Keychain
  (`security … -s zdots -a ZDOTS_O2_ROOT_PASSWORD`) and execs the binary. The
  plist contains only `[openobserve-ctl, serve]`.

## Configuration

Pinned in `bin/openobserve-ctl`:

| Setting | Value |
|---|---|
| Version | `0.90.3` (darwin-arm64) |
| Tarball sha256 | `328660dc…611304` (verified on download) |
| Data dir | `${XDG_DATA_HOME:-~/.local/share}/openobserve` |
| Log | `~/.local/state/zsh/openobserve.log` |
| Root email | `root@zdots.local` |
| Root password | Keychain `zdots / ZDOTS_O2_ROOT_PASSWORD` |
| Retention | 3 days home / 2 days work (`ZDOTS_O2_RETENTION_DAYS`) |
| Size drift warning | 8 GB (`ZDOTS_O2_SIZE_WARN_GB`, surfaced by `zdots-doctor`) |

## Migration (Z-134) — complete

The containerized LGTM stack (Grafana/Loki/Tempo/Mimir) is fully removed.
Observability is native end-to-end: apps → OTel Collector → OpenObserve
(`otlp_http/openobserve` → `:5080/api/default`), served at `o2.localhost`. The
collector carries no LGTM exporter, `bin/local-ci` no longer manages an LGTM
stack, and the archived compose file is deleted. Nothing in the observability
path depends on Colima/Docker.

## Troubleshooting

```bash
openobserve-ctl status        # running? healthy?
openobserve-ctl logs          # tail the log
zsvc diag o2                  # status + health + launchd + recent log
```

If the service flaps, check the log for a port clash on `:5080`/`:5081` or a
data-dir permission problem. Boot reads creds from Keychain — if `creds
--show-password` is empty, run `openobserve-ctl install` to re-provision.
