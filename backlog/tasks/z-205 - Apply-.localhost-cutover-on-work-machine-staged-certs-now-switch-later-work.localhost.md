---
id: Z-205
title: >-
  Apply .localhost cutover on work machine (staged: certs now, switch later; +
  work.localhost)
status: Done
assignee: []
created_date: '2026-07-10 21:00'
updated_date: '2026-07-11 17:10'
labels:
  - nginx
  - localhost
dependencies: []
priority: medium
ordinal: 100895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
decision-011 migrated the 4 zdots vhosts (llama/embed/o2/zdots) .local->.localhost. This session PULLED the repo change but Phase 3 (the live nginx cutover) was NOT applied on this work machine — it is operator/sudo-gated (cc-hook-guard blocks Claude Code from nginx/cert ops).

Verified 2026-07-10 on this machine:
- LIVE nginx serves .local for all vhosts (llama/embed/o2/zdots/my/work).
- Cert SANs are .local-only (no .localhost).
- REPO has the 4 zdots vhosts on .localhost; zdots' my.conf was removed (Z-198, ~/my-owned).
- The home machine has ALREADY cut over to .localhost.
- CAUTION: zdots.localhost / my.localhost currently return 200 here, but that is the false-green decision-011 documents — no live .localhost server_name, so they fall through to work.conf's `listen 80 default_server` (Work app), NOT the real backends. On this machine .local is what actually reaches zdots/context-engine.

Goal: bring this machine to .localhost in STAGES — certs first (non-switching, safe anytime), vhost switch later when ready; work.local->work.localhost handled separately as Work work wraps.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Stage 1: cert covers the union of all .local AND .localhost SANs; live .local keeps working after the reload
- [x] #2 Stage 2: live server_names for llama/embed/o2/zdots are .localhost and each reaches its real backend (redirect-blind, no _dashboard_session cookie)
- [x] #3 work.local -> work.localhost migrated and the nginx default_server decision recorded
- [x] #4 my.localhost aligned via ~/my; stale .local /etc/hosts pins pruned
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
STAGE 1 — CERTS NOW (non-switching, safe): regenerate the shared cert to cover the UNION of current .local + incoming .localhost names. Extra SANs are harmless while vhosts stay .local. Pre-include work.localhost (forward-looking).
  mkcert -cert-file "$(brew --prefix)/etc/nginx/certs/zdots-local.pem" \
         -key-file  "$(brew --prefix)/etc/nginx/certs/zdots-local-key.pem" \
    llama.localhost embed.localhost o2.localhost zdots.localhost gemstash.localhost my.localhost dev.my.localhost work.localhost \
    llama.local embed.local o2.local zdots.local gemstash.local my.local dev.my.local work.local grafana.local \
    localhost 127.0.0.1
  sudo launchctl kickstart -k system/homebrew.mxcl.nginx    # reload to load new cert; routing UNCHANGED (vhosts still .local)
  ** do NOT run nginx-regen-certs for this stage — it ALSO deploys the .localhost vhosts (that IS the switch). Use manual mkcert to stay cert-ready without switching. **

STAGE 2 — SWITCH ZDOTS VHOSTS (HOLD until ready): deploy the repo .localhost vhosts + reload.
  nginx-regen-certs        # deploys tracked .localhost vhosts, re-derives cert SANs, validates (nginx -t), graceful reload, backs out on failure
  then optionally prune the 4 stale /etc/hosts .local pins — .localhost needs none (RFC 6761).

STAGE 3 — WORK (pulled into the cutover 2026-07-11 by operator instruction): work
dashboard repo (~/github.com/work/dashboard) fully flipped — ops/nginx/work.conf
server_names -> work.localhost, dev config.hosts entry dropped (Rails dev default
already allows .localhost), links.yml/layout hostname-classifier/comments updated.
Deploy = cp ops/nginx/work.conf to the live servers dir before the reload.
DEFAULT_SERVER DECISION (AC#3, recorded): the :80 default stays the stock nginx.conf
welcome block (it already holds `listen 80 default_server`; nginx-ctl status probes it).
The :443 default — where the false-green lived (audit 2026-07-11: EVERY .localhost name
200'd from Work with a _dashboard_session cookie) — becomes the tracked
etc/nginx/servers/00-default.conf: `listen 443 ssl default_server`, return 404 with an
X-Zdots-Default marker header. Unmatched names now fail loudly and self-diagnose.

STAGE 4 — MY.LOCALHOST (this machine, socket-preserving): the work ~/my checkout has NO
ops/nginx source (home's my.conf proxies 127.0.0.1:7010; this box's Puma binds
unix:/tmp/my_prod.sock — a verbatim copy would 502). my.conf stays deployed-only here:
flip it in place to server_name my.localhost keeping the socket proxy_pass (staged copy
prepared by the session). Clean flip, no my.local 308 (decision-011 convention; diverges
from home — reconcile when ~/my syncs). bin/deploy verify URL fixed to my.localhost/up
(redirect-blind) on the ~/my side.

GEMSTASH (added 2026-07-11, postdates this task): gemstash.localhost joins the cutover —
tracked vhost etc/nginx/servers/gemstash.conf (proxy → 127.0.0.1:9292), name in
nginx-ctl HOSTS (health + SAN union), gemstash.local /etc/hosts pin pruned with the rest.
Bundler mirror deliberately STAYS on http://127.0.0.1:9292 — Ruby's OpenSSL does not
read the macOS keychain, so bundler cannot verify the mkcert CA without SSL_CERT_FILE
plumbing that buys nothing on a loopback-only mirror.

VERIFY each switch (redirect-blind + IDENTITY — the decision-011 false-green lesson):
  for h in llama embed o2 zdots gemstash my work; do printf '%s.localhost: ' "$h"; curl -sk "https://$h.localhost" -o /dev/null -w '%{http_code}\n' --max-redirs 0; done
  Then confirm the zdots names carry NO _dashboard_session (Work) cookie — a bare 200 is not proof; it was 200 before, for the wrong reason.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CUTOVER APPLIED 2026-07-11 (all four stages collapsed into one session by operator instruction).

EVIDENCE:
- AC#1 cert: 19-SAN union minted (mkcert output: 8x .localhost incl gemstash+work, 8x legacy .local, grafana.local, localhost, 127.0.0.1), expires 2028-10-11. Backups .bak-20260711-114216.
- AC#2 identity (redirect-blind, --max-redirs 0): llama/embed 415 on / + 200 on /health (real llama-server), o2 308→/web/ (real O2), zdots 200 no cookie (statusd), gemstash 302 no cookie, my.localhost 200 + _context_engine_session cookie, /up 200 via unix socket. NO _dashboard_session on any zdots name. TLS trusted without -k (system curl 200).
- AC#3 work: work.localhost 200 + _dashboard_session (correct backend). Dashboard repo commit 68a5eb7 (conf, config.hosts dropped — Rails dev default allows .localhost, link classifier, links.yml). default_server decision: stock nginx.conf keeps :80 default (welcome page, nginx-ctl status probes it); tracked 00-default.conf takes :443 default → 404 + X-Zdots-Default header. Verified: nonesuch.localhost AND retired zdots.local both 404 + X-Zdots-Default. False-green class dead (pre-switch audit: ALL .localhost names 200'd from Work).
- AC#4 my: live my.conf → my.localhost keeping unix:/tmp/my_prod.sock (work checkout has no ops/nginx source; home proxies :7010 — reconcile on ~/my sync). ~/my commit be03259 fixes bin/deploy verify to my.localhost/up redirect-blind. /etc/hosts prune pending operator sudo (7 pins).
- DoD#2 make check: bin/check requires an interactive shell (fzf-tab widget probe) — cannot run from the CC harness; operator to run in terminal. bats platform_e2e+docs_contract+gemstash: 44/46, only reds are pre-existing Z-206 (stale methodology count) and Z-207 (zdots_rw fence, filed high).
- zdots commits: 8af8a59 (cutover prep), 1347820 (Z-206/Z-207), aftermath commit follows.

CLOSE-OUT 2026-07-11:
- /etc/hosts pruned by operator: zero .local pins remain (verified grep -c = 0). The .localhost names resolve with no pins (RFC 6761) and no mDNS stall.
- DoD#2 make check: red is PRE-EXISTING and unrelated — bin/check hard-requires the fzf-tab-complete widget but the fzf-tab formula is not installed and is in no Brewfile (fails identically in the operator's interactive terminal). Filed as its own agent issue. Cutover-relevant suites: platform_e2e + docs_contract + gemstash = 44/46, both reds pre-existing and tracked (Z-206/Z-207).
- Final state: zsvc health — all six LOCAL_URLS green on real health paths; identity verified per AC#2/AC#3 evidence above.
- Commits: zdots 8af8a59 + 1347820 + ef3a348 (+ backlog close-out), ~/my be03259, work dashboard 68a5eb7.

POST-CLOSE UPDATE 2026-07-11: make check now PASSES 769/769 — the fzf-tab red was resolved by installing the formula (Z-208 Done, Brewfile.common updated). DoD#2 fully satisfied.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [x] #2 make check passes with output captured in task notes or commit message
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
