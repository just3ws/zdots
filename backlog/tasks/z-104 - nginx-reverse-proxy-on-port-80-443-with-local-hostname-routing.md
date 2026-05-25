---
id: Z-104
title: 'nginx: reverse proxy on port 80/443 with local hostname routing'
status: To Do
assignee: []
created_date: '2026-05-25 13:52'
labels:
  - nginx
  - infra
  - local-dev
dependencies: []
references:
  - docs/local-ai.md
  - lib/ai_boundary.bash
priority: medium
ordinal: 2890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure nginx as a proper reverse proxy on port 80/443 for all HTTP services on this machine. Goals:
- nginx listens on port 80 (and 443) rather than 8080
- Local hostname routing: custom subdomains per service (e.g. llama.local, grafana.local)
- Let's Encrypt or local CA for TLS (mkcert or step-ca for loopback certs)
- dnsmasq or /etc/hosts for custom local hostnames
- Upstream proxying to: llama-server (:8080), Grafana, any other services

Current state: nginx stopped (`brew services stop nginx`) to free port 8080 for llama-server. Homebrew default nginx listens on *:8080 which conflicts with llama-server's 127.0.0.1:8080 via SO_REUSEPORT.

Approach:
1. Move nginx to port 80 in nginx.conf (not 8080)
2. Configure upstream blocks per service
3. Add server_name blocks for local subdomains
4. Set up dnsmasq for *.local resolution
5. Generate local TLS certs with mkcert (or step-ca for proper PKI)
6. Update ZDOTS_AI_ENDPOINT and related vars if proxied paths change
7. Verify ai_boundary.bash still enforces RFC-1918 (127.0.0.1 loopback direct, not through proxy)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 nginx listens on port 80 (not 8080)
- [ ] #2 llama-server reachable at http://llama.local or similar
- [ ] #3 brew services start nginx succeeds without conflicting with llama-server
- [ ] #4 ai_boundary.bash still rejects non-loopback endpoints (proxy must stay on loopback)
- [ ] #5 zdots-ctl check passes after nginx changes
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
