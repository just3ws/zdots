---
id: Z-320
title: '[agent-issue] nginx client_body_temp permission denied on large POST bodies'
status: To Do
assignee: []
created_date: '2026-08-25 00:20'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 195895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `0da81e366c1376725b06026f66347382`

The shared local nginx instance (proxying wwworkremote.localhost and others) 500s on any POST whose body is large enough to spill from memory to disk. /opt/homebrew/var/run/nginx is drwx------ owned by mike, but the nginx worker process runs as user 'nobody' (per worker_processes/user directives), so the worker can't even traverse into that directory to reach client_body_temp once it needs to. Confirmed via nginx error log: 'open() "/opt/homebrew/var/run/nginx/client_body_temp/0000000004" failed (13: Permission denied)', request POST /api/v0/outcomes/greenhouse, host wwworkremote.localhost. A ~89KB POST (Indeed outcome sync) stayed under nginx's in-memory client_body_buffer_size and never hit this; a ~337KB POST (Greenhouse outcome sync, same feature) did and 500'd instantly (0.03s, before ever reaching the Rails/Puma upstream -- confirmed by hitting Puma directly on :31000, which returned 200 with the correct result). Fix is one line: chown -R nobody /opt/homebrew/var/run/nginx (or chmod the parent dir so group/other can traverse -- whichever matches how the other Homebrew-nginx-fronted local sites in this instance are set up, since gemstash.conf/zdots.conf/wwworkremote.conf all share this one nginx). Did not patch it myself per the standing rule (zdots owns shared local infra). Workaround in place: wwworkremote's Chrome extension already defaults every API call to http://localhost:31000 directly, bypassing nginx entirely, so this doesn't block the app -- it only matters if something intentionally routes a large POST through the https-fronted hostname.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
