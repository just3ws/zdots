---
id: decision-011
title: .localhost TLD migration for loopback-only nginx vhosts
date: '2026-07-03 15:40'
status: accepted
---
## Context

Four nginx vhosts front loopback-only services: `llama.local` (Qwen3-8B
inference), `embed.local` (Nomic embeddings), `o2.local` (OpenObserve), and
`zdots.local` (the Observable Control Plane status console, drafted
2026-06-25 in commit `effca79` but never fully deployed — see the operator
handoff below). All four used the `.local` TLD, each requiring a static
`/etc/hosts` entry (`127.0.0.1 <name>`) on every machine that uses them.

This surfaced two problems in the same session:

1. **A false-positive health check.** Verifying `zdots.local` after deploying
   it, `curl -sk https://zdots.local -o /dev/null -w '%{http_code}'` reported
   `200` — but that was `curl` silently following a redirect chain through
   nginx's default-SSL-vhost fallback into `my.localhost`'s app, not the
   intended backend. `--max-redirs 0` was needed to see the true `308` first
   hop. This class of error (green check, wrong service) is exactly what
   AGENTS.md's "Snake in a Can" calls a spring snake — recoverable once
   caught, but only because it was checked twice.

2. **An undocumented precedent already existed.** `~/my`'s `context-engine`
   cockpit was set up 2026-06-16 (`~/my` commit `e17028c`) as `my.localhost`,
   with `my.local` kept only as a legacy 308 redirect to it
   (`~/my/docs/structure.md:8`: *"Use `my.localhost` for the private browser
   cockpit"*). No ADR or comment recorded why — the choice had to be
   reconstructed from `git log` and empirical testing three weeks later,
   prompting the question this decision closes: *why wasn't this written
   down the first time?*

Reconstructing the `my.localhost` rationale empirically (`dscacheutil -q host
-a name <made-up-name>.localhost` resolves to `127.0.0.1` with **zero**
`/etc/hosts` configuration) confirmed the technical case:

- **`.localhost` is IANA-reserved** (RFC 6761 §6.3): every OS resolver and
  browser is required to treat `*.localhost` as loopback, unconditionally,
  with no DNS or network round-trip. No `/etc/hosts` entry is needed or
  consulted.
- **`.local` is the mDNS/Bonjour namespace** (RFC 6762): resolution depends on
  either a static `/etc/hosts` pin (what this platform did) or live multicast
  broadcast. A static pin only protects the machine that has it — any other
  device on the same LAN without that pin resolves `<name>.local` via mDNS,
  which is a *real* namespace: if some other host (a printer, an IoT device,
  or literally any Mac named "zdots" in Sharing preferences) ever advertises
  itself as `<name>.local`, a client without the override could resolve to
  that device instead of loopback. `.localhost` cannot collide this way —
  it is never a livemDNS name any real device can claim.

Two Macs on the same LAN with identical `/etc/hosts` pins for the same
`.local` name do **not** conflict with each other (the file is per-machine,
never broadcast) — but the exposure to a *third*, unpinned machine on that
network is real, and the whole class of exposure disappears with
`.localhost`.

## Decision

**Migrate all four loopback-only zdots vhosts from `.local` to `.localhost`,
clean cutover, no legacy redirect:**

| Old | New |
|---|---|
| `llama.local` | `llama.localhost` |
| `embed.local` | `embed.localhost` |
| `o2.local` | `o2.localhost` |
| `zdots.local` | `zdots.localhost` |

**Clean cutover, not transition:** unlike `my.localhost` (which kept `my.local`
as a permanent 308 redirect — an already-bookmarked, user-facing cockpit),
these four are single-user, loopback-only dev/infra endpoints with no external
bookmarks or muscle memory to preserve. A redirect vhost is pure surface area
for no benefit. `/etc/hosts` entries for the four names are removed;
`my.local`/`my.localhost`/`dev.my.local` are unaffected (out of scope — owned
by `~/my`, already following this pattern since June).

**`root@zdots.local`, the OpenObserve root-account email, is explicitly NOT
touched.** It is a credential identity string (`bin/openobserve-ctl`,
`docs/openobserve.md`, `docs/otel-collector-guide.md`), not a hostname — a
blind find-and-replace across the codebase would have silently corrupted it.
Every edit in this migration was scoped past that string.

## Consequences

- **`etc/nginx/servers/zdots.conf`** (zdots-owned; `my.conf` is `~/my`-owned
  and untouched): all four `server_name` directives updated, no redirect
  blocks added.
- **Executable consumers updated** to stop hardcoding `.local`: `bin/zsvc`
  (health-check URLs), `bin/nginx-ctl` (`HOSTS` array — the source `nginx-regen-certs`
  greps for cert SANs), `bin/nginx-regen-certs` (grep pattern widened to
  `\.local(host)?$`, hardcoded `zdots.local` references), `bin/zdots-ctl`
  (mkcert fix-suggestion text; the `/etc/hosts` presence check for these three
  names is removed — nothing to check once resolution is RFC-guaranteed),
  `bin/bootstrap` (fresh-install mkcert command and `_NEEDED_HOSTS`),
  `bin/zdots-statusd`/`-ctl` and `lib/svc-registry.bash` (cosmetic: title,
  comments, service-registry description string), `bin/agent-guide`
  (cosmetic).
- **`bin/zdots-endpoints` required a real fix, not a rename.** Its discovery
  was entirely `/etc/hosts`-grep-based (`*.local` pattern) — once the four
  names stop needing hosts entries, that discovery would have silently gone
  blind to them. Rewired to source `*.localhost` names from the deployed
  nginx `server_name` directives it already parsed for cross-checking
  (implicitly loopback, per RFC 6761 — no IP lookup needed), while `*.local`
  discovery still requires an explicit `/etc/hosts` pin (unchanged behavior,
  now documented as intentional per this decision rather than the only
  option).
- **Cert regeneration and `/etc/hosts`/nginx reload are operator-only steps**
  (`cc-hook-guard` blocks Claude Code from touching nginx or certs on this
  PHI-adjacent machine) — see the runbook below.
- **Test suite**: `tests/platform_e2e.bats` had two hardcoded `llama.local`
  assertions, updated to `llama.localhost`; full suite re-run confirmed zero
  regressions beyond the pre-existing baseline failure set.
- **Filed, not fixed** (adjacent, out of this decision's scope): zdots' own
  `etc/nginx/servers/my.conf` is a stale copy (still `my.local`-canonical,
  `/tmp/my_prod.sock`) diverged from the real `~/my`-owned source; its header
  claims `bin/bootstrap` deploys it, which would clobber the live
  `my.localhost` config if bootstrap ever runs again on this machine
  (`zdots-issue` filed).

## Operator runbook (cc-hook-guard boundary — not automatable from Claude Code)

```bash
# 1. Regenerate the cert with the new SANs (keep every existing name — union,
#    never drop). nginx-regen-certs computes this automatically:
nginx-regen-certs            # deploys the tracked configs, regenerates the
                              # cert, validates, reloads — backs out on failure

# 2. Remove the now-unnecessary /etc/hosts entries (manual — bootstrap and
#    zdots-ctl no longer manage these three; leave zdots.local's entry alone
#    only if you still want it as a manual bridge during transition):
sudo sed -i '' '/^127\.0\.0\.1 llama\.local$/d;/^127\.0\.0\.1 embed\.local$/d;/^127\.0\.0\.1 o2\.local$/d;/^127\.0\.0\.1 zdots\.local$/d' /etc/hosts

# 3. Verify redirect-blind (the false-green from this session's zdots.local
#    check — --max-redirs 0 shows the true first hop, not the final one):
for h in llama embed o2 zdots; do
  printf '%s: ' "$h.localhost"
  curl -sk "https://$h.localhost" -o /dev/null -w '%{http_code}\n' --max-redirs 0
done
```
