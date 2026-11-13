---
id: Z-365
title: nginx on high ports as a user LaunchAgent (no root, no 80/443)
status: To Do
assignee: []
created_date: '2026-11-13T19:54:00Z'
labels:
  - services
  - deferred
dependencies: []
priority: low
ordinal: 242895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Machines where another dev stack owns 80/443, or where a root LaunchDaemon and sudo are unwelcome, cannot run the zdots nginx tier. *.localhost always resolves to loopback, so the vhosts work on any port.

Proposal: ZDOTS_NGINX_HTTP_PORT / ZDOTS_NGINX_HTTPS_PORT (default 80/443, so existing machines are unchanged) templated into etc/nginx/servers/*.conf; above 1024, nginx-ctl runs nginx as a user LaunchAgent (no sudo); ZDOTS_NGINX_TLS=0 serves plain HTTP on loopback and skips nginx-regen-certs (mkcert needs a trusted local CA, a system trust change some machines must not make). zdots-endpoints, nginx-ctl health and svc-registry endpoints read the ports. Candidate ports: 44380 (HTTP), 44443 (HTTPS).

Deferred 2026-11-13: dashboards and local telemetry are not needed on the current machine; stability comes first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Vhosts listen on the configured ports; defaults leave 80/443 unchanged
- [ ] #2 High ports run nginx as a user LaunchAgent with no sudo
- [ ] #3 TLS off serves plain HTTP and skips certificate steps
- [ ] #4 zdots-endpoints and zsvc health probe the configured ports
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
