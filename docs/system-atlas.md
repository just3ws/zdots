# System Atlas

The System Atlas is the read-only, LAN-facing map of the local system. Open
[`https://lan.just3ws.com`](https://lan.just3ws.com) on the trusted local
network, or use [`https://zdots.localhost/map`](https://zdots.localhost/map)
on this Mac. The LAN root redirects to `/map`.

## Visual model

The map uses a **connectionist topography**: nodes are things an operator can
visit or diagnose; links are runtime dependencies or request routes. The page
starts at the network edge and moves inward through routing, applications, and
shared infrastructure. The areas are neighborhoods, not deployment tiers or
trust boundaries. Select a node to see its owner, process, port, manager, live
signal, URL, and immediate connections.

This combines a 10,000-foot orientation view with drill-down links to the
system's existing consoles:

- `zdots.localhost` for the Observable Control Plane, manuals, docs, command
  help, and local diagnostics.
- `my.localhost/panoramic` for Context Engine Panoramic View and runtime
  observations; `/platform` shows service health.
- `media-pipeline.lan.just3ws.com` for media intake, transcription, and
  publication operations.
- `o2.localhost` and `jaeger.localhost` for telemetry and trace inspection.

The topology catalog is [`etc/system-topology.json`](../etc/system-topology.json).
It records ownership, links, hostnames, process, port, lifecycle manager, and
coordinates in one place. Coordinates are hand-tuned for readability. Update
the catalog and this page together when ownership, routing, or dependency
relationships change.

## Reading live state

`/map.json` is a small, read-only snapshot derived from `zsvc list`,
`zdots-ctl status --json`, and two application `/up` routes. The page refreshes
it every 30 seconds. It includes only a timestamp, summary counts, coarse
process state, and boolean application health. It omits PIDs, logs, disk
paths, command output, backlog content, and diagnostic details.

The map separates three ideas:

- **Configured topology** means the relationship exists in the catalog.
- **Healthy / unhealthy** means a configured application or platform health
  check passed or failed.
- **Running / stopped** means `zsvc list` reports the process state when no
  stronger health signal is available.
- **Not checked / unobserved** means this status source does not report health
  or process state for that node. It does not mean the service is down.

Use `zdots-endpoints` to probe configured nginx URLs, `zdots-ctl status` for
the core platform, `zsvc diag <service>` for launchd and logs, and the linked
application consoles for application-specific checks. The System Atlas does
not start workers, run repairs, expose controls, or claim that a route works
because a node is drawn.

## Runtime layers

```mermaid
flowchart TB
    Browser[Operator browser on trusted LAN] -->|hostname lookup| DNS[Local DNS · Bastion :53]
    DNS -->|A record resolves to Mac| Nginx[nginx :80 / :443]
    Browser -->|HTTPS request| Nginx
    Nginx -->|lan.just3ws.com: /map and /map.json only| Atlas[zdots-statusd :11600]
    Nginx -->|zdots.localhost| Zdots[zdots console]
    Nginx -->|my.localhost| Context[Context Engine :7010]
    Nginx -->|media-pipeline.lan.just3ws.com| Media[media-pipeline :32000]
    Nginx -->|hister.localhost| Hister[Hister :4433]
    Nginx -->|wwworkremote.localhost| WWR[WWWorkRemote :31000]
    Nginx -->|phalanxduel.localhost| Phalanx[Phalanx Duel :5173 / :3103]
    Context --> PG[(PostgreSQL :5432 / database my)]
    Context --> Bus[Message Bus coordinator · optional]
    Bus --> PG
    Bus --> Redis[(Redis :6379)]
    Context --> Llama[Inference :11500]
    Context --> Embed[Embeddings :11501]
    Context --> OTel[OTel Collector :4317 / :4318]
    Media --> Llama
    Media --> OTel
    Zdots --> OTel
    OTel --> O2[OpenObserve :5080]
    OTel --> Jaeger[Jaeger :16686]
```

The catalog includes additional local endpoints such as Redis, Gemstash, the
async worker, optional Colima and Message Bus coordinator, and the static
portfolio.
`docs/platform-map.md`, `docs/platform-service-plane.md`, and
`docs/local-url-routing.md` provide the ownership, lifecycle, and hostname
views. For the media-pipeline cockpit, open
[media-pipeline.lan.just3ws.com](https://media-pipeline.lan.just3ws.com). Its
machine setup and recovery guidance is in the repository
[owner's manual](https://github.com/just3ws/media-pipeline/blob/main/docs/owners-manual.md).

The LAN map is reachable from a browser on the local network. Most
`*.localhost` dashboards are loopback-only and therefore open on this Mac,
not on a phone. The current dedicated LAN application route is
`media-pipeline.lan.just3ws.com`; the other app links are labeled “this Mac”.

## LAN route activation

The source vhost in `etc/nginx/servers/zdots.conf` exposes only `/`, `/map`,
and `/map.json` for `lan.just3ws.com`; all other paths return 404. It shares
the existing statusd backend but never exposes the wider `zdots.localhost`
route tree.

After reviewing the vhost, deploy tracked nginx sources and activate the
certificate through the existing privileged workflow:

```bash
nginx-regen-certs && nginx-ctl validate && nginx-ctl reload
```

`nginx-regen-certs` deploys tracked vhosts, regenerates certificate SANs, and
validates/reloads nginx. These commands may prompt for sudo.

The DNS wildcard configured for `*.lan.just3ws.com` should resolve the name to
this Mac. Confirm from a LAN client with `https://lan.just3ws.com/` and
`https://lan.just3ws.com/map.json`. `https://lan.just3ws.com/docs` must return
404. The vhost is not active until that privileged deploy step succeeds.

## Maintenance contract

When the service inventory changes:

1. Update `etc/system-topology.json` with a source-backed owner, process,
   port, manager, health key, URL, and links.
2. Update the Mermaid and routing tables in `docs/platform-map.md`,
   `docs/platform-service-plane.md`, and `docs/local-url-routing.md` where the
   topology or ownership changed.
3. Update the relevant project's user guide and command `--help`/man page when
   an operator workflow changes.
4. Check the server and catalog syntax, run mandoc lint, and validate nginx
   after installing the source vhost:

   ```bash
   ruby -c bin/zdots-statusd
   ruby -rjson -e 'JSON.parse(File.read("etc/system-topology.json"))'
   mandoc -Tlint man/man1/zdots-statusd.1
   nginx-ctl validate
   ```
5. Rebuild graph artifacts through the repository's documented graphify
   workflow after code or topology changes; inspect generated diffs before
   committing them.

Runtime service state is a timestamped observation, not durable topology
documentation. Do not copy a live green/red state into the static maps.
