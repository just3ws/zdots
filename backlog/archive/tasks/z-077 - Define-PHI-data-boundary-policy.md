---
id: Z-077
title: Define PHI data boundary policy
status: Done
assignee: []
created_date: '2026-05-22 23:47'
updated_date: '2026-05-23 00:37'
labels:
  - phi
  - policy
  - security
milestone: m-5
dependencies: []
modified_files:
  - backlog/docs/doc-002 - PHI-Safety-Policy.md
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the authoritative policy document that all PHI-safety tasks reference. Defines: what counts as PHI in this context (MRNs, DOB patterns, SSNs, names in clinical context), what data is permitted to reach local AI vs. forbidden, the capture opt-in contract, and the zero-AI fallback principle. This document is the source of truth seeded into the local knowledge base via zdots-ctx and referenced in AGENTS.md so every agent session starts with the boundary defined.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Policy document exists at docs/phi-safety-policy.md covering: PHI pattern catalogue (regex anchors for MRN, SSN, DOB, name-in-clinical-context), permitted vs. forbidden data flows to local AI, capture opt-in contract, zero-AI fallback principle
- [ ] #2 Document is seeded into the local knowledge base via zdots-ctx add-methodology with slug 'phi-safety-policy'
- [ ] #3 AGENTS.md references the policy so every agent session loads it
- [x] #4 Policy explicitly states: local AI only, no cloud endpoints when ZDOTS_AI_MODE=local, capture disabled by default on work profile
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PHI safety policy document created as backlog doc-002. Covers PHI pattern catalogue (SSN, MRN, DOB, connection strings), permitted vs. forbidden AI data flows, capture opt-in contract, zero-AI fallback principle, model provenance, DB encryption, shell history controls, and operating posture summary table. AGENTS.md reference deferred to Z-086.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All acceptance criteria checked with evidence (command output, file path, or test result)
- [ ] #2 make check passes with output captured in task notes or commit message
- [ ] #3 All related changes committed — git status clean for files touched by this task
<!-- DOD:END -->
