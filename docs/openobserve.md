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
open http://127.0.0.1:5080  # UI  (or https://o2.local once the vhost lands — Phase 3)
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
- OpenObserve only reads `ZO_ROOT_USER_PASSWORD` on **first init**, so a password
  set/rotated later won't match the UI. The fix is not to protect the data — it's
  to re-init cleanly:

  ```bash
  openobserve-ctl reinit            # wipe data dir; root re-created from Keychain
  openobserve-ctl reinit --rotate   # also generate a fresh Keychain password first
  ```

  `reinit` guards the path before any `rm -rf`, stops the service, wipes
  `ZO_DATA_DIR`, and restarts. Streams re-populate from the collector within ~15s.
- **Retention** defaults to 14 days (`ZDOTS_O2_RETENTION_DAYS` →
  `ZO_COMPACT_DATA_RETENTION_DAYS`) so the store self-trims instead of growing
  unbounded.

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
| Retention | 14 days (`ZDOTS_O2_RETENTION_DAYS`) |

## Migration status (Z-134)

- **Phase 1 (done):** OpenObserve stood up natively, running alongside LGTM.
- **Phase 2:** repoint the OTel Collector exporter `otlphttp/lgtm` (`:4418`) to
  OpenObserve (`:5080/api/default`, basic-auth), validated in parallel, then drop
  LGTM from the traces/metrics/logs pipelines.
- **Phase 3–4:** `o2.local` nginx vhost + cert; confirm all three signals land.
- **Phase 5:** tear down LGTM (`bin/local-ci`, `etc/docker-compose.lgtm.yaml`),
  reclaim the Colima VM on home.
- **Phase 6:** docs/doctor/check finalization.

## Troubleshooting

```bash
openobserve-ctl status        # running? healthy?
openobserve-ctl logs          # tail the log
zsvc diag o2                  # status + health + launchd + recent log
```

If the service flaps, check the log for a port clash on `:5080`/`:5081` or a
data-dir permission problem. Boot reads creds from Keychain — if `creds
--show-password` is empty, run `openobserve-ctl install` to re-provision.
