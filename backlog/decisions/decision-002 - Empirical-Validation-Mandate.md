---
id: decision-002
title: Empirical Validation Mandate (Confirmed & Verified)
date: '2026-03-27 09:45'
status: Accepted
---

## Context
The complexity of modular shell environments makes assumptions dangerous. "I believe" or "I think" without verification often leads to regressions in different execution contexts (interactive vs non-interactive, TTY vs non-TTY, Mac vs Linux).

## Decision
Adopt a strict project standard where all shell modifications MUST be verified with empirical evidence before being considered complete.

1. **Discovery over Assumption**: Every hypothesis must be tested.
2. **Standardized Verification**: Use the following tools for verification:
    - `bin/check`: Full regression suite.
    - `bin/capabilities`: Environment contract validation.
    - `bats tests/`: Targeted unit/integration tests.
    - Direct command output: Showing the delta in `PATH`, `SETOPT`, or behavior.
3. **Traceability**: All verification steps should be recorded in the task notes or commit messages.

## Consequences

**Positive:**
- **Zero-Regression Policy**: Ensures that fixes for one environment don't break others.
- **High-Signal Feedback**: Failures are caught early and provide descriptive errors.
- **Agent Reliability**: Provides AI agents with a clear "Definition of Done".

**Negative:**
- **Higher Friction**: Development takes slightly longer due to the mandatory testing phase.
