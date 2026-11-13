---
id: Z-363
title: >-
  [agent-issue] llama-ctl model-download skipped sha256 verification for
  Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf (ba
status: Done
assignee: []
created_date: '2026-11-13T17:33:00Z'
updated_date: '2026-11-13T20:12:00Z'
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause: zdots_model_verify returned success when a file had no entry in lib/llama-models.sha256, so a newly added model was never checked. Fix: at download time (repo known) an unlisted file is checked against the sha256 Hugging Face publishes (x-linked-etag of the resolve redirect); with no hash from either source it fails closed unless ZDOTS_MODEL_ALLOW_UNVERIFIED=1. Service start (no repo) stays manifest-only so it never needs the network. Pinned Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf in the manifest. Tests: tests/model_store.bats (7, fake curl). On the work Mac: Instruct verified from the manifest; the unlisted Thinking GGUF verified live against Hugging Face. The "Bad request." line was not reproduced.
<!-- SECTION:FINAL_SUMMARY:END -->
