---
id: Z-232
title: >-
  [agent-issue] zdots-ctx query (full-text) returns 0 hits for everything —
  likely broken by content encryption cutover
status: Done
assignee: []
created_date: '2026-07-15 22:38'
updated_date: '2026-07-24 18:09'
labels:
  - agent-reported
  - error
dependencies: []
priority: high
ordinal: 111895
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** high
**Trace ID:** `64fc7ae163a5227411ce047015e86825`

Found during /command-qc audit. 'zdots-ctx query zsvc' and 'zdots-ctx query tooling:zsvc' return 0 hits, yet the data exists: 'zdots-ctx query --semantic' returns the tooling:zsvc methodology, and 'zdots-ctx hydrate tooling-catalog' returns the full catalog. Hypothesis: FTS searches the plaintext content columns, which emptied when content moved to content_enc/context_enc (363/363 lessons, 113/113 methodologies encrypted). Impact: AGENTS.md rule zero directs every agent to 'zdots-ctx query tooling:<name>' before external tools — that contract silently returns nothing, pushing agents to claim missing context or reach for external tools. Expected: FTS over decrypted content, or query transparently falling back to semantic.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause narrowed: the blanket '0 hits for everything' was fixed earlier by the decrypt-scan cutover (b01b4dbba, 2026-06-29). The surviving gap was slug matching: Methodology.text_match? scanned content+title but not slug, so 'zdots-ctx query tooling:<name>' (rule-zero contract) missed catalog entries whose identity lives in the slug. Fixed in a0a79af (+ regression spec spec/zdots/models/methodology_search_spec.rb). Verified: 'zdots-ctx query tooling:zsvc' now returns the methodology; lessons text search confirmed working (77 hits for 'token').
<!-- SECTION:NOTES:END -->
