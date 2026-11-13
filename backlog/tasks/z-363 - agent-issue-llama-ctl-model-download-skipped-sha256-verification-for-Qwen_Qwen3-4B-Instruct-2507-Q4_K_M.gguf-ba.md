---
id: Z-363
title: >-
  [agent-issue] llama-ctl model-download skipped sha256 verification for
  Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf (ba
status: To Do
assignee: []
created_date: '2026-11-13T17:33:00Z'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 240895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `7a084f400fe91d285e4b113951e052c5`

llama-ctl model-download skipped sha256 verification for Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf (bartowski) — output shows 'downloaded … (2.3G)' then 'Bad request.' and no 'verifying'/'verified' lines, exit 0. Other downloads the same day verified. Manual check matched HF x-linked-etag, so the file is fine; the verify step fails open.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->
