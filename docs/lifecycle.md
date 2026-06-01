# Project Lifecycle & Learning Guide

This guide covers the full lifecycle of a Zdots contribution, from environment setup to production diagnostics.

---

## 1. Onboarding & Setup (The Beginning)

Zdots is a "platform-in-a-repo." Getting started requires aligning your local environment with the platform's expectations.

### Bootstrap
Run the bootstrap script to install dependencies (Homebrew, Ruby, Node, etc.) and configure the base shell.
```bash
bin/bootstrap
```

### Verification
Ensure the platform is "Green" before doing any work.
```bash
zdots-ctl status
zsvc health
```

---

## 2. Task Orchestration (The Middle)

Every change in Zdots is tracked via an issue and a task.

### Starting a Task
Use `ztask` to start a new task. This hydrations your environment with the task context and prepares the brain.
```bash
ztask start Z-123 "Fix llama-server timeout"
```

### Recording Progress
Significant findings should be recorded in the `~/my/context/` directory or filed as follow-up issues using `zdots-issue`.

---

## 3. Development & Verification (The Workflow)

### Fast Feedback
Use `make` for quick checks.
```bash
make check-fast   # syntax + style
make test         # run unit tests
```

### Integration Testing
Use `bats` for full E2E validation of the service plane.
```bash
bats tests/platform_e2e.bats
```

---

## 4. Observability & Diagnostics (The "Now")

When things go wrong, use the consolidated diagnostic suite.

### Global Health
Check the status of all services and their local URL endpoints.
```bash
zsvc health
```

### Consolidated Logs
Tail all service logs at once to find inter-service communication errors (e.g., Nginx → Llama).
```bash
zsvc logs all
```

### Deep Dive
If a specific service is failing, use `diag` for a comprehensive report.
```bash
zsvc diag postgres
```

---

## 5. Troubleshooting Tutorial: "The Local URL Failure"

Scenario: `zsvc health` reports `llama.local` is `fail` with code `000`, but core services are healthy.

**Step 1: Verify Core Services**
```bash
zsvc health
# Result: llama-server is 'ok', but llama.local is 'fail'.
```

**Step 2: Check Logs for Proxied Errors**
```bash
zsvc logs all
# Look for 'upstream timed out' or 'connection refused' in nginx logs.
```

**Step 3: Diagnose Nginx**
```bash
zsvc diag nginx
# Check if nginx is running and if its config is valid.
```

**Step 4: Check DNS/Hosts**
Ensure `llama.local` resolves to `127.0.0.1`.
```bash
ping -c 1 llama.local
```

**Step 5: Verify Upstream**
Ensure the service is listening on the port Nginx expects (see `zsvc list`).
```bash
zsvc list
curl -I http://127.0.0.1:11500/health
```

---

## 6. How-Tos for Common Scenarios

| How do I... | Command |
|---|---|
| Reset the full platform? | `zdots-ctl reset` |
| See all log file paths? | `zsvc logs all --paths` |
| Get JSON health for a script? | `zsvc health --json` |
| Check my shell's performance? | `make bench` |
| Query the brain? | `zdots-ctx query "term"` |
| Update AI patterns? | `fabric-ai --updatepatterns` |
| Capture a new code snippet? | `zdots-ctx capture path/to/file.zsh` |

---

## 7. Performance Standards

All shell modifications must be benchmarked.
- **Goal**: `< 0.08s` for interactive shell startup.
- **Tool**: `make bench` or `hyperfine "zsh -i -c exit"`.

If startup exceeds 0.1s, the shell is considered "Degraded" and must be optimized.
