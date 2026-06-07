# Local URL Routing (nginx)

nginx fronts the local services behind friendly `*.local` HTTPS URLs (mkcert TLS).
It is a **root LaunchDaemon** in launchd's *system* domain because it binds the
privileged ports 80/443 — managed via `bin/nginx-ctl` (which uses `sudo launchctl`,
**never** `sudo brew services`, see `bin/nginx-repair`), and wired into `zsvc`.

## Topology

| URL | nginx upstream | Backed by | zsvc service |
|-----|----------------|-----------|--------------|
| `https://llama.local`     | `127.0.0.1:11500` | llama-server (Qwen3-8B) | `zsvc llama` |
| `https://embed.local`     | `127.0.0.1:11501` | llama-embed (Nomic)     | `zsvc embed` |
| `https://o2.local`        | `127.0.0.1:5080`  | OpenObserve (logs/metrics/traces) | `zsvc o2` |
| `https://my.local`        | `unix:/tmp/my_prod.sock` | context-engine (Rails, prod) | — |
| `https://dev.my.local`    | `unix:/tmp/my_dev.sock`  | context-engine (Rails, dev)  | — |

- nginx config: `/opt/homebrew/etc/nginx/` — `nginx.conf` includes `servers/*`
  (`zdots.conf` = AI/infra, `my.conf` = context-engine). Certs in `certs/`.
- Control: `zsvc nginx {status|health|reload|restart|start|stop|logs}` →
  `bin/nginx-ctl`. Use `reload` after editing `servers/*.conf` (validates first,
  zero-downtime); `restart` only for a full bounce.

## Wiring check

```bash
zsvc list                 # nginx now appears (system-domain state)
zsvc nginx status         # loaded + listening on :80
zsvc nginx health         # per-host HTTP codes (502 = nginx up, backend down)
nginx-ctl validate        # sudo nginx -t
```

## Known gaps

Status as of 2026-05-30. Severity: 🔴 breaks a URL · 🟡 latent/ops · ⚪ pre-existing.

| # | Gap | Sev | State |
|---|-----|-----|-------|
| 1 | `llama.local`→`:8080` / `embed.local`→`:8090` were **stale**; services run on 11500/11501 | 🔴 | **Fixed** in `servers/zdots.conf`; run `zsvc nginx reload` (sudo) to apply |
| 2 | nginx was a root LaunchDaemon but **not managed by `zsvc`** | 🟡 | **Fixed** — `bin/nginx-ctl` + `zsvc nginx` |
| 3 | `grafana.local`→`:3000` Grafana | ⚪ | **Resolved (Z-134)** — LGTM/Grafana retired; observability moved to `o2.local`→`:5080` (native OpenObserve), freeing `:3000` |
| 4 | `my.local`/`dev.my.local` down — context-engine **bundle not installed** (`bundle check` → rails 8.1.2 etc. missing), sockets absent | ⚪ | **Open** — pre-existing; needs `bundle install` in `~/my/context-engine`, then boot bound to `/tmp/my_dev.sock` |
| 5 | `/etc/hosts`: `177.0.0.1 lgtm.local` **typo** | ⚪ | **Resolved (Z-134)** — lgtm.local retired; drop the hosts line |
| 6 | `lgtm.local` in `/etc/hosts` but **no nginx server block** | ⚪ | **Resolved (Z-134)** — retired with the LGTM stack |
| 7 | nginx `servers/*.conf` + `/etc/hosts` live **outside the repo** (not version-controlled); lost on rebuild | 🟡 | **Open** — consider symlinking from `etc/nginx/` or templating in bootstrap |
| 8 | `pg_hba.conf` scram rules (DB auth fence) **not version-controlled** | 🟡 | **Open** — capture in bootstrap so a Postgres rebuild re-applies them |

### Fix snippets

```bash
# Gap 1 — apply the port fix (graceful, validated):
zsvc nginx reload

# o2.local — add the hosts entry for the OpenObserve vhost (needs sudo):
echo '127.0.0.1 o2.local' | sudo tee -a /etc/hosts && nginx-ctl reload
# (and drop the retired lgtm.local line if present)

# Gap 4 — bring up the context-engine UI:
( cd ~/my/context-engine && bundle install && bin/rails server )   # binds /tmp/my_dev.sock per puma.rb
```

> Resolution note: `*.local` resolves via `/etc/hosts` (verified: `ping my.local`,
> `dscacheutil -q host -a name llama.local` → 127.0.0.1). A `000` from `curl` in a
> sandboxed/non-interactive context is a resolver artifact there, not a routing gap.
