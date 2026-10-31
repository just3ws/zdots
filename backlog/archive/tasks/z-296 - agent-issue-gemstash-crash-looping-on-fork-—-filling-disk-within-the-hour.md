---
id: Z-296
title: '[agent-issue] gemstash crash-looping on fork() — filling disk within the hour'
status: Done
assignee: []
created_date: '2026-08-07 18:17'
updated_date: '2026-08-07 20:06'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 171895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** critical
**Trace ID:** `6c2b280e6d47707657cc35934e3c6cc6`

zsvc status shows gemstash 'ok, running (PID 851)' but the log is a runaway crash loop:
  objc[PID]: +[NSCharacterSet initialize] may have been in progress in another thread when fork() was called.
  We cannot safely call it or ignore it in the fork() child process. Crashing instead.

Ran log-rotate gemstash manually (4426MB -> 412MB compressed archive) at 13:14. By 13:16 (2 min later) the freshly-truncated log was already back to 24MB, with 576 repeats of the crash block and 2448 crash/exception/signal/abort mentions. At that rate this refills to critical (500M) size in well under an hour and risks exhausting the ~13GB free disk zdots-doctor already flagged as low.

The parent process (PID 851) never dies -- zsvc/launchd see it as healthy -- so nothing currently notices or stops the loop; only the log-size doctor check (and now this manual investigation) caught it.

Known macOS mitigation for this exact ObjC/fork interaction: OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES in the child's env, but that masks rather than fixes whatever gemstash is fork()ing for -- operator call on whether that's an acceptable workaround or whether gemstash needs to stop forking (e.g. switch a gem-fetch subprocess call to spawn instead of fork, or pin a gem version whose fetch path forks).

Also: the weekly com.zdots.log-rotate LaunchAgent (Sun 03:15) is otherwise working correctly (confirmed clean run history every Sunday since 06-28) -- it's just too infrequent for this crash-loop's burst rate. Not proposing a schedule change without your sign-off since gemstash's actual growth rate should return to normal once the crash loop itself is fixed.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root-caused, not worked around: gemstash's own default puma_workers=1 makes Puma run clustered (Puma::Cluster), which calls Process.fork to spawn its single worker. On this macOS/Ruby combo that fork crashes instantly against the ObjC runtime's fork-safety check (NSCharacterSet init race) -- confirmed in puma-8.0.2 lib/puma/launcher.rb: clustered? = workers > 0. The master process survives and retries the worker spawn in a tight loop, which is what produced the ~1GB/2min log growth.

Fix: added ':puma_workers: 0' to the config gemstash-ctl init generates (bin/gemstash-ctl). workers:0 selects Puma::Single -- no fork, no cluster -- which also matches the design intent already documented in that file (one coherent in-memory cache, no need for multiple processes).

Verified: regenerated config, started service, single 'puma 7.2.1 (tcp://127.0.0.1:9292)' process (no child processes), HTTP 200 on /, log stayed at 165 bytes of normal access-log lines over a 15s observation window (previously: gigabytes in minutes). gemstash-ctl restored to running state.
<!-- SECTION:NOTES:END -->
