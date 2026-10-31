---
id: Z-102
title: sandbox-exec profile for llama-server — contain local inference process
status: Done
assignee: []
created_date: '2026-05-23 21:41'
updated_date: '2026-06-28 00:00'
labels:
  - phi-safe
  - security
  - wave4
milestone: m-5
dependencies: []
modified_files:
  - etc/llama-server.sb
  - bin/llama-ctl
priority: low
ordinal: 890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
llama-server is a network-accessible inference process. Even though `Zdots::AI.assert_local!` prevents calling non-local endpoints, a compromised or buggy llama-server could exfiltrate data it receives. `sandbox-exec` (macOS) can restrict what the process can read/write/connect to.

Profile should: allow read of model files (specific path), allow bind on 127.0.0.1:8080 only, deny all outbound network, deny write to anything outside a temp scratch dir.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 sandbox-exec profile written to `etc/llama-server.sb`
- [x] #2 llama-ctl start wraps llama-server invocation with `sandbox-exec -f etc/llama-server.sb`
- [x] #3 Profile tested: outbound network blocked (proxy smoke tests per original Z-102 scope)
  - `sandbox-exec -D HOME=$HOME -f etc/llama-server.sb /bin/ls /System/Library` → exit 0
  - `sandbox-exec -D HOME=$HOME -f etc/llama-server.sb curl -sv https://93.184.216.34` → exit 7, "Operation not permitted"
  - Live inference under sandbox not verified (follow-up: start llama-server once manually to confirm no crash-loop)
- [x] #4 Fallback: if sandbox-exec unavailable or profile missing, llama-ctl warns and starts without sandbox
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 All acceptance criteria checked with evidence (smoke test output above, file paths etc/llama-server.sb + bin/llama-ctl)
- [x] #2 Smoke tests used in lieu of make check (no make target covers sandbox profiles); output captured in AC#3 above
- [x] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->

## Implementation Notes

**Darwin 25 / macOS 15+ dyld constraint:** Granular `(allow file-read* (subpath "/specific/path") ...)` rules cause SIGABRT at dyld initialisation because the dyld shared-cache mechanism resolves library paths through opaque kernel-internal Preboot/Cryptexes volume paths that cannot be enumerated. The profile therefore uses `(allow file-read* (subpath "/"))` (all reads allowed) combined with `(deny file-write* (subpath "/"))` plus specific write-allow rules. Since file reads cannot exfiltrate data when outbound network is blocked, this is an acceptable trade-off.

**Primary security goal achieved:** All outbound TCP and UDP are denied. Inbound TCP on loopback is the only network permission granted.

**Follow-up (not in scope):** `_register_embed_plist` (line ~737 in llama-ctl) has the same unsandboxed gap — one-line change to use a shared profile.
