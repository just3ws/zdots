# Local URL Routing (nginx)

nginx fronts the local services behind friendly HTTPS URLs (mkcert TLS).
Loopback-only zdots vhosts use the `*.localhost` TLD (decision-011: RFC 6761 —
every resolver hard-wires it to loopback, no `/etc/hosts` entry needed, and no
mDNS/Bonjour name-collision exposure the way `.local` carries). `my.localhost`,
`wwworkremote.localhost`, and `just3ws.localhost` are each owned by their own
project (`~/my`, `~/github.com/wwworkremote/wwworkremote`, `~/github.com/just3ws/
just3ws.github.io` respectively) and follow the same pattern independently —
none of the three are zdots platform services; nginx just fronts them on this
machine alongside the ones zdots does own.
It is a **root LaunchDaemon** in launchd's *system* domain because it binds the
privileged ports 80/443 — managed via `bin/nginx-ctl` (which uses `sudo launchctl`,
**never** `sudo brew services`, see `bin/nginx-repair`), and wired into `zsvc`.

## Topology

`zdots-endpoints` discovers deployed nginx names and probes them; use it for
live state. This table is the compact ownership map. The deployed nginx
configuration is machine state, partly managed by related repositories, so
changes to it must be reconciled with those owners and validated through
`nginx-ctl` (sudo required).

| Host(s) | Purpose / owner | Backend |
|---------|-----------------|---------|
| `llama.localhost`, `embed.localhost` | Local inference / zdots | llama :11500, embeddings :11501 |
| `o2.localhost`, `jaeger.localhost` | Observability / zdots | OpenObserve :5080; Jaeger :16686 |
| `zdots.localhost` | zdots status console | statusd :11600 |
| `gemstash.localhost` | RubyGems cache / zdots | Gemstash service |
| `my.localhost` | Knowledge Layer console / my | context-engine :7010 |
| `my.local` | Legacy context-engine alias | Redirects to `my.localhost`; currently responds |
| `dev.my.local` | Legacy context-engine development hostname | Still configured to `/tmp/my_dev.sock`; endpoint probe currently returns 502 |
| `wwworkremote.localhost`, `wwwr.localhost` | wwworkremote project aliases | Rails app :31000 |
| `media-pipeline.localhost`, `pipeline.localhost` | media-pipeline project aliases | media-pipeline service |
| `hister.localhost`, `www.hister.localhost` | Hister search / project | static UI plus Hister backend |
| `www.just3ws.localhost`, `just3ws.localhost` | just3ws portfolio / project | static Jekyll site; bare name redirects to `www` |
| `phalanxduel.localhost`, `play.phalanxduel.localhost`, `admin.phalanxduel.localhost` | Phalanx Duel / project | static site, game client :5173, admin :3103 |

Trusted-LAN names (`lan.wwworkremote.com` and Phalanx Duel `*.lan.phalanxduel.com`)
are also served by nginx but are not `.localhost` hosts. They are project-owned
and intentionally omitted from the loopback host list.

`www.just3ws.localhost` has **no backend process** — nginx serves the last
`jekyll build` output directly off disk (`try_files`). It cannot *receive* a
request-time query or run any logic. It already *sends*, though: Jekyll's
build emits static data exports (`resume.json`, `exports/resume.md`,
`exports/portfolio.md`) that `wwworkremote/wwworkremote` fetches by plain GET — see
`docs/just3ws-interop-protocol.md` in that repo. Confirmed via O2 trace:
`wwworkremote` fetched `https://just3ws.github.io/resume.json` (the published
GitHub Pages copy, not the local vhost, in the traced call). Any two-way or
request-time integration would still need a real backend built first; the
static-export path already works today and needs nothing further here.

### Trusted-LAN phone access (`lan.wwworkremote.com`)

wwworkremote/wwworkremote replaced its earlier `.home.arpa` trusted-LAN names with a
real DNS record, `lan.wwworkremote.com` (its own DNS, own `server_name`,
tracked in `~/github.com/wwworkremote/wwworkremote/ops/nginx/servers/wwworkremote.conf`
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

Certificate cleanup (Z-325) is implemented by `nginx-regen-certs --prune`.
The dry run on 2026-10-31 found three stale SANs to drop: `zdots.local`,
`wwworkremote.home.arpa`, and `wwwr.home.arpa`. No certificate was changed;
the shared certificate still contains them. Review the printed drop list and
coordinate the certificate update/reload before applying `--prune`.

## Deploy workflow (context-engine)

```bash
cd ~/my/context-engine && bin/deploy   # bundle install → assets:precompile → restart Puma → verify /up
```

- nginx config: `/opt/homebrew/etc/nginx/` — `nginx.conf` includes `servers/*`
  (`zdots.conf` = AI/infra, tracked here; `my.conf` = context-engine, tracked
  and deployed from `~/my/context-engine/ops/nginx/servers/my.conf` — not
  zdots' concern, see decision-011 / Z-198). Certs in `certs/`.
- Control: `zsvc status nginx`, `zsvc health nginx`, `zsvc reload nginx`, or
  `zsvc restart nginx` → `bin/nginx-ctl`. Use `zsvc reload nginx` after editing
  `servers/*.conf` (validates first, zero-downtime); `zsvc restart nginx` only
  for a full bounce. nginx is a root LaunchDaemon, so lifecycle actions cross
  the sudo boundary.

## Wiring check

```bash
zsvc list                 # nginx now appears (system-domain state)
zsvc status nginx         # loaded + listening on :80
zsvc health nginx         # service health; 502 means nginx is up, backend down
zdots-endpoints            # inventory and probe deployed vhosts
nginx-ctl validate        # sudo nginx -t
```

## Current exceptions

| Host / boundary | Current evidence | Next decision |
|---|---|---|
| `dev.my.local` | Still present in the tracked context-engine source and deployed nginx config; `zdots-endpoints` reports 502 because `/tmp/my_dev.sock` has no healthy upstream | Retire the stale vhost and its certificate name, or restore a real dev cockpit. No change made here |
| `wwworkremote.localhost`, `wwwr.localhost` | Both return 502 while the optional local Rails app is stopped | Expected for an on-demand project; start its native app when needed. Do not treat this as a zdots platform outage |
| `play.phalanxduel.localhost`, `admin.phalanxduel.localhost` | Both return 502 while local game/admin development servers are stopped | Expected for on-demand project development; production deploy is independent and uses Fly's remote build path |
| `media-pipeline.localhost` | Endpoint probe reaches the app but reports its mkcert certificate as untrusted | Check local CA trust with `mkcert -install` if browsers reject the route; no trust-store change was made |
| `my.local` | Redirects to the healthy `my.localhost` cockpit | Keep as a compatibility alias or retire it with a coordinated config/certificate update |
| `grafana.local`, `lgtm.local` | `/etc/hosts` still maps both to 127.0.0.1, but neither has an nginx vhost; Z-134 retired the services | Remove the stale mappings via privileged host-config maintenance; Z-356 tracks this. No change made here |
| Deployed nginx files | Each project owns its source; nginx serves copies under `/opt/homebrew/etc/nginx/servers/` | After a source change, sync/validate and reload through `zsvc reload nginx`; root lifecycle needs sudo |
| Retired certificate names | `nginx-regen-certs --dry-run --prune` reports three removable SANs; the current shared certificate still contains them | Review the dry-run and apply `nginx-regen-certs --prune` when ready |

> Resolution note: zdots-owned loopback vhosts use `*.localhost`; macOS
> resolves these to loopback without `/etc/hosts` entries (decision-011).
> `/etc/hosts` still contains retired `grafana.local` and `lgtm.local` aliases;
> Z-356 tracks their removal. A rollback copy exists on Dock_1TB. The edit
> requires operator sudo authentication and has not been applied. A `000` from
> `curl` in a sandboxed/non-interactive context may be a resolver artifact. A
> `200` where you expect a different backend may mean `curl` followed a
> redirect — check with `--max-redirs 0` before trusting a green health check.
