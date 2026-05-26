#!/usr/bin/env bash
# lib/lifecycle.bash — Compatibility shim.
#
# All functions have moved to focused modules:
#   lib/svc-health.bash   — health checks, OTel, output helpers (all platforms)
#   lib/svc-launchd.bash  — macOS launchd lifecycle (sources svc-health)
#   lib/svc-process.bash  — PID-based background processes (sources svc-health)
#
# New callers should source the focused module they need directly.
# This shim exists only to avoid breaking callers that haven't been updated yet.

source "${BASH_SOURCE[0]%/*}/svc-launchd.bash"
source "${BASH_SOURCE[0]%/*}/svc-process.bash"
