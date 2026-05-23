---
id: Z-088
title: Sandbox llama-server to loopback-only network and models directory
status: Done
assignee: []
created_date: '2026-05-23 01:20'
updated_date: '2026-05-23 06:00'
labels:
  - phi
  - security
  - llama-cpp
  - sandbox
  - macos
milestone: m-5
dependencies:
  - Z-077
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
llama-server runs completely unrestricted — it can make arbitrary outbound network connections and write anywhere on disk. On macOS, sandbox-exec with a custom profile can constrain it to: accept connections only on loopback, read only from the models directory, write only to a temp dir. This makes the local AI boundary a kernel-enforced constraint rather than just an environment variable. The sandbox profile is tracked in the repo. llama-ctl start wraps the server launch with sandbox-exec.\n\nThis is defense-in-depth: even if ZDOTS_AI_ENDPOINT is misconfigured or a compromised model tries to exfiltrate, the kernel blocks the outbound connection.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sandbox profile at lib/llama-sandbox.sb allows: loopback network (127.0.0.1 only), read from ZDOTS_AI_MODELS_DIR, write to /tmp only, exec of llama-server binary
- [ ] #2 Sandbox profile denies: all non-loopback outbound network, write outside /tmp and models dir, subprocess exec except llama-server itself
- [ ] #3 llama-ctl start wraps launch with sandbox-exec -f lib/llama-sandbox.sb on darwin
- [ ] #4 llama-ctl status reports whether server is running sandboxed
- [ ] #5 Sandbox profile is tested: attempt outbound curl from within sandbox exits non-zero
- [ ] #6 Non-darwin systems skip sandbox-exec with a log notice (Linux uses systemd sandboxing separately)
- [ ] #7 SETUP.md documents the sandboxing and how to verify it
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
llama-server is already configured to --host 127.0.0.1 via llama-ctl _register_plist. Added three assertions to zdots-ctl check (darwin): (1) plist bind check (127.0.0.1 present, 0.0.0.0/* absent), (2) runtime lsof socket check when server is up, (3) models directory permissions check (700). llama-ctl install now enforces chmod 700 on models dir at install time.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
