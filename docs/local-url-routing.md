# Local URL Routing (nginx)

nginx fronts the local services behind friendly HTTPS URLs (mkcert TLS).
Loopback-only zdots vhosts use the `*.localhost` TLD (decision-011: RFC 6761 —
every resolver hard-wires it to loopback, no `/etc/hosts` entry needed, and no
mDNS/Bonjour name-collision exposure the way `.local` carries). `my.localhost`,
`wwworkremote.localhost`, and `just3ws.localhost` are each owned by their own
project (`~/my`, `~/github.com/wwworkremote/core`, `~/github.com/just3ws/
just3ws.github.io` respectively) and follow the same pattern independently —
none of the three are zdots platform services; nginx just fronts them on this
machine alongside the ones zdots does own.
It is a **root LaunchDaemon** in launchd's *system* domain because it binds the
privileged ports 80/443 — managed via `bin/nginx-ctl` (which uses `sudo launchctl`,
**never** `sudo brew services`, see `bin/nginx-repair`), and wired into `zsvc`.

## Topology

| URL | nginx upstream | Backed by | zsvc service |
|-----|----------------|-----------|--------------|
| `https://llama.localhost` | `127.0.0.1:11500` | llama-server (Qwen3-8B) | `zsvc llama` |
| `https://embed.localhost` | `127.0.0.1:11501` | llama-embed (Nomic)     | `zsvc embed` |
| `https://o2.localhost`    | `127.0.0.1:5080`  | OpenObserve (logs/metrics/traces) | `zsvc o2` |
| `https://zdots.localhost` | `127.0.0.1:11600` | zdots-statusd (Observable Control Plane) | `zsvc status` |
| `https://my.localhost`    | `127.0.0.1:7010`  | context-engine (Rails, prod) | — |
| `https://wwworkremote.localhost` (alias `wwwr.localhost`) | `127.0.0.1:31000` | wwworkremote/core (Rails/Falcon or Puma, dev) | — |
| `https://lan.wwworkremote.com` | `127.0.0.1:31000` (same upstream as above) | wwworkremote/core, trusted-LAN access (e.g. phone) | — |
| `https://www.just3ws.localhost` | *(none — static files)* | prebuilt Jekyll `_site/`, synced to `/opt/homebrew/var/www/just3ws.github.io` by `bin/install-localhost`; **canonical** | — |
| `https://just3ws.localhost` | *(301 → `www.`)* | bare host + all `:80` traffic redirect to the canonical `www.just3ws.localhost`, mirroring prod (`just3ws.com` → `www.just3ws.com`) | — |

`www.just3ws.localhost` has **no backend process** — nginx serves the last
`jekyll build` output directly off disk (`try_files`). It cannot *receive* a
request-time query or run any logic. It already *sends*, though: Jekyll's
build emits static data exports (`resume.json`, `exports/resume.md`,
`exports/portfolio.md`) that `wwworkremote/core` fetches by plain GET — see
`docs/just3ws-interop-protocol.md` in that repo. Confirmed via O2 trace:
`wwworkremote` fetched `https://just3ws.github.io/resume.json` (the published
GitHub Pages copy, not the local vhost, in the traced call). Any two-way or
request-time integration would still need a real backend built first; the
static-export path already works today and needs nothing further here.

### Trusted-LAN phone access (`lan.wwworkremote.com`)

wwworkremote/core replaced its earlier `.home.arpa` trusted-LAN names with a
real DNS record, `lan.wwworkremote.com` (its own DNS, own `server_name`,
tracked in `~/github.com/wwworkremote/core/ops/nginx/servers/wwworkremote.conf`
— not zdots' concern beyond fronting it, same as `my.localhost`/
`just3ws.localhost`). nginx routes it to the same upstream as
`wwworkremote.localhost` (`127.0.0.1:31000`) via `server_name`, and its cert
coverage is handled by the Z-324 fix: `nginx-regen-certs` now scans every
deployed vhost's `server_name` for SANs, so any TLD works, not just
`.local`/`.localhost`.

The phone gets a self-signed-cert warning on first connect because it doesn't
trust the local mkcert CA (only this machine does, via `mkcert -install`) —
expected, not a bug; proceeding past the warning is the accepted trust model
here, same tradeoff as any dev-only mkcert setup. Confirmed working
2026-08-26: phone on LAN → `lan.wwworkremote.com` → cert warning → accept →
served homepage.

Known gap (Z-325, filed, not yet resolved): `nginx-regen-certs` only ever
*adds* SANs — it unions with whatever's already in the cert by design ("a
name that already worked is never silently dropped"), so the retired
`.home.arpa` names are still sitting in the cert's SAN list after a fresh
regen. Harmless (unused SAN in a private cert), but they won't fall out on
their own; a future `--prune` mode would need to rebuild the list purely from
currently-live sources instead of unioning with the old cert.

## Deploy workflow (context-engine)

```bash
cd ~/my/context-engine && bin/deploy   # bundle install → assets:precompile → restart Puma → verify /up
```

- nginx config: `/opt/homebrew/etc/nginx/` — `nginx.conf` includes `servers/*`
  (`zdots.conf` = AI/infra, tracked here; `my.conf` = context-engine, tracked
  and deployed from `~/my/context-engine/ops/nginx/servers/my.conf` — not
  zdots' concern, see decision-011 / Z-198). Certs in `certs/`.
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
| 4 | `my.local` down — context-engine bundle/boot | ⚪ | **Resolved (2026-06-19)** — launchd-managed Puma at `/tmp/my_prod.sock`; dashboard live; `dev.my.local` eliminated (plist deleted, nginx block removed) |
| 5 | `/etc/hosts`: `177.0.0.1 lgtm.local` **typo** | ⚪ | **Resolved (Z-134)** — lgtm.local retired; drop the hosts line |
| 6 | `lgtm.local` in `/etc/hosts` but **no nginx server block** | ⚪ | **Resolved (Z-134)** — retired with the LGTM stack |
| 7 | nginx `servers/*.conf` + `/etc/hosts` live **outside the repo** (not version-controlled); lost on rebuild | 🟡 | **Open** — consider symlinking from `etc/nginx/` or templating in bootstrap |
| 8 | `pg_hba.conf` scram rules (DB auth fence) **not version-controlled** | 🟡 | **Open** — capture in bootstrap so a Postgres rebuild re-applies them |

### Fix snippets

```bash
# Gap 1 — apply the port fix (graceful, validated):
zsvc nginx reload

# .localhost names (llama/embed/o2/zdots) need NO /etc/hosts entry — RFC 6761
# hard-wires them to loopback. Regenerate the cert + deploy configs instead:
nginx-regen-certs

# Restart Puma only (no asset change):
touch ~/my/context-engine/tmp/restart.txt
```

> Resolution note: every vhost is a `*.localhost` name since the Z-205 cutover
> (2026-07-11); the legacy `*.local` `/etc/hosts` pins are pruned. `.localhost`
> needs no entry at all — every resolver hard-wires it to loopback per RFC
> 6761 (verified: `dscacheutil -q host -a name llama.localhost` → 127.0.0.1
> with zero `/etc/hosts` configuration; see decision-011). A `000` from `curl`
> in a sandboxed/non-interactive context is a resolver artifact there, not a
> routing gap. A `200` where you expect a different backend may mean `curl`
> silently followed a redirect — check with `--max-redirs 0` before trusting
> a green health check.
