# ADR-0001: nginx is not in the CLI AI-query path

**Status:** Accepted  
**Date:** 2026-05-25

## Context

nginx is deployed as a local reverse proxy (`https://llama.local`, `https://embed.local`)
serving the llama.cpp chat server (port 11500) and embedding server (port 11501) over TLS
via mkcert-issued certs. The question arose: should CLI tools (`ai-query`, `zdots-ask`,
the Ruby pipeline) route through nginx rather than hitting the backends directly?

Two constraints made the answer non-trivial:

1. **`lib/ai_boundary.bash` locality check** — `_zdots_is_local_endpoint` validates that
   `ZDOTS_AI_ENDPOINT` resolves to a loopback or RFC-1918 address by regex-matching the
   hostname. It passes `127.x`, `10.x`, `192.168.x`, `localhost`, `::1`. It does not
   resolve DNS names, so `https://llama.local` would fail the check in `local` mode and
   block all AI calls.

2. **TLS overhead on loopback** — traffic between CLI tools and backends stays on
   `127.0.0.1`. TLS on a loopback socket adds latency and cert-management complexity
   with no meaningful confidentiality benefit on a single machine.

## Decision

CLI tools (`ai-query`, `zdots-ask`, `lib/zdots/ai/client.rb`, `sbin/zdots-brain`) use
direct loopback endpoints:

- Chat: `ZDOTS_AI_ENDPOINT=http://127.0.0.1:11500` (default)
- Embed: `ZDOTS_AI_EMBED_ENDPOINT=http://127.0.0.1:11501` (default)

nginx serves `https://llama.local` and `https://embed.local` for browser and human
`curl` access only. It is not in the hot path for any automated AI call.

Extending `_zdots_is_local_endpoint` to resolve `*.local` names (DNS lookup + loopback
assertion) was considered and deferred — it adds complexity for no security gain on a
single machine.

## Consequences

- The boundary check remains a fast, purely lexical IP regex — no DNS calls, no
  external dependencies.
- All loopback AI traffic is plaintext between processes on the same host. This is
  acceptable; the threat model for local AI calls is data exfiltration to the network,
  not loopback interception.
- nginx provides HTTPS termination, streaming headers (`X-Accel-Buffering`), and
  request logging for any browser or external client that needs it.

## Revisit when

- **Container or LAN access** — if AI backends become reachable from Docker containers
  or other machines on the local network (e.g. `powerstation.local`), the loopback
  assumption breaks. At that point `_zdots_is_local_endpoint` needs DNS resolution or
  an explicit allowlist, and TLS via nginx becomes meaningful.
- **nginx logging** — if per-request AI audit logging at the proxy layer is required
  (e.g. for compliance), routing CLI tools through nginx makes the log centralised.
- **mTLS or API key injection** — if backends need per-client identity, nginx is the
  natural place to inject headers; CLI tools would then route through it.
