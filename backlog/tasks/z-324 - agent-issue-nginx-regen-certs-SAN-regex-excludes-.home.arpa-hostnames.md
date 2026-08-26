---
id: Z-324
title: '[agent-issue] nginx-regen-certs SAN regex excludes .home.arpa hostnames'
status: To Do
assignee: []
created_date: '2026-08-26 17:52'
labels:
  - agent-reported
  - request
dependencies: []
priority: medium
ordinal: 199895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** request
**Severity:** medium
**Trace ID:** `670b410751ba35a052c13a5e0e60669f`

Running wwworkremote/core's ops/nginx/deploy.sh calls nginx-regen-certs to pick up new server_name entries wwwr.home.arpa and wwworkremote.home.arpa added to ops/nginx/servers/wwworkremote.conf. nginx-regen-certs builds its mkcert SAN list from (1) the existing cert's current SANs, (2) nginx-ctl's HOSTS=(...) array filtered through the regex \.local(host)?$, and (3) a few hardcoded names (zdots.localhost, localhost, 127.0.0.1). That regex only matches .local/.localhost suffixes, so .home.arpa names are never picked up from HOSTS, and they are not in the existing cert either (verified via openssl x509 -noout -ext subjectAltName on $(brew --prefix)/etc/nginx/certs/zdots-local.pem -- SANs listed llama/embed/o2/zdots/my/just3ws/gemstash/wwworkremote/wwwr .localhost names plus my.local/dev.my.local/zdots.local, no .home.arpa entries). Expected: running nginx-regen-certs after adding a trusted-LAN .home.arpa server_name to a deployed vhost produces a cert that actually covers that hostname. Actual: the regenerated cert silently omits it, so nginx routes the hostname correctly but any TLS-validating client (e.g. a phone) gets a certificate hostname-mismatch error. The gap is easy to miss because nginx-regen-certs's own reload check and deploy.sh's post-deploy verification both use curl -sk (skips cert validation), so nothing in the normal flow surfaces the mismatch. Suggested fix: extend SAN-gathering to pick up hostnames actually served by the deployed vhosts under $CONF_DIR/servers/*.conf (any TLD), not just nginx-ctl's .local/.localhost HOSTS array. Separately, note this ticket itself hit the known Z-314 misroute bug on first attempt: running zdots-issue from inside wwworkremote/core (cwd-resolved backlog) filed it as task-91 in that repo's own Backlog.md instead of zdots', with the failure surfacing only as 'unknown ID' rather than a hard error. Deleted the stray task-91 file from wwworkremote/core and re-ran from $ZDOTDIR to file this correctly -- Z-314 is still To Do and just reproduced live.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
