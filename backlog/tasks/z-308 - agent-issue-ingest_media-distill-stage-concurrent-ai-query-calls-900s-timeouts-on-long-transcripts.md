---
id: Z-308
title: >-
  [agent-issue] ingest_media distill stage: concurrent ai-query calls + 900s
  timeouts on long transcripts
status: To Do
assignee: []
created_date: '2026-08-22 14:39'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 183895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `28225baa0b9f7d11763a5b390655697d`

During ingest_media job 0ca627a9 (transcription b408dcb3, 22-min YouTube video), the distilled stage's single ai-query call exceeded DISTILL_LOCAL_TIMEOUT=900s and the job was retried by the queue's backoff (fail_job: next_run_at = now + 2^attempts min, dead at attempts>=5). This burned 2 of the job's 5 total attempts on an otherwise-successful pipeline (raw/whisper had already succeeded) and nearly hit the dead-job ceiling.

Observed anomaly: at one point (ps aux, ~08:46) three separate 'bash bin/ai-query --timeout 900 Distill this transcript...' processes were running concurrently with near-identical start timestamps (within 2s of each other), all with byte-identical prompt boilerplate. lib/zdots/jobs/ingest_media.rb's run_stage/PIPELINE.each and ai_distill's windows.map are both sequential Ruby (no Thread.new, no Process.spawn found in sbin/zdots-brain or ingest_media.rb) — I could not find a code path that would legitimately produce 3 concurrent ai-query invocations from one job run. llama-server runs with --parallel 1 (single inference slot, Apple Silicon memory-bound — confirmed intentional), so if 3 calls really were in flight simultaneously they'd serialize behind each other, which would fully explain repeated 900s timeouts via queue pile-up (a retried call queuing behind a still-running earlier call that Zdots.run_bounded's kill_group didn't actually stop server-side, since ai-query posts with stream:false — a client-side curl --max-time kill on a non-streaming request may not abort llama.cpp's in-flight/queued generation).

Could not fully confirm root cause from static code reading — filing for operator review rather than guessing at a fix. Worth checking: (1) whether the 3 concurrent processes were a real pile-up bug or a ps artifact/stale unrelated processes I misread, (2) whether bounded_run's process-group kill on timeout reliably closes the curl socket in a way llama.cpp's non-streaming handler detects, (3) whether DISTILL_LOCAL_TIMEOUT=900s is adequate headroom for a full-transcript (no windowing, single call) distill on a ~22min video under --parallel 1 load.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
