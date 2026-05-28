---
id: decision-001
title: Local CI Execution with Colima and Act
date: '2026-03-25 22:32'
status: Accepted
---

## Context
Developing and debugging GitHub Actions workflows traditionally requires a slow feedback loop: committing code, pushing to a remote branch, and waiting for the GitHub runners to pick up and execute the job. This "commit-and-pray" cycle pollutes Git history with "WIP" commits and significantly slows down iteration, particularly when diagnosing environment-specific failures in shell configuration scripts (`bin/check`). 

Furthermore, running the tests on macOS-hosted runners locally is difficult because macOS containers are not natively available on local developer machines in the same way Linux containers are.

## Decision
We will use **[act](https://github.com/nektos/act)** in combination with **[Colima](https://github.com/abiosoft/colima)** to execute GitHub Actions locally. 

1. **Colima as the Container Runtime:** Rather than relying on the heavy Docker Desktop application, we use Colima to provide a lightweight, CLI-driven Linux VM on macOS. It exposes a standard Docker socket (`/var/run/docker.sock`) that tools natively expect.
2. **Act for Workflow Execution:** We use `act` to parse `.github/workflows/*.yml` and run them inside Docker containers.
3. **Linux Proxy for macOS Jobs:** Since local macOS images are unavailable, we instruct `act` to map `macos-latest` jobs to a standard Ubuntu container (`catthehacker/ubuntu:act-latest`). 
4. **Conditional Environment Fallbacks:** We update the GitHub Actions workflow (`check.yml`) to gracefully handle the Linux environment (e.g., dynamically installing `zsh` if it's missing) while remaining transparent to the official macOS runners on GitHub.
5. **Makefile Abstraction:** We abstract the underlying container and runner complexity via a new `bin/local-ci` script and `Makefile` targets (`make ci-up`, `make ci-run`, etc.), providing a standardized, repeatable entry point for developers and AI agents.

## Consequences

**Positive:**
- **Rapid Iteration:** Developers and agents can run the full CI suite locally in seconds, receiving immediate feedback without touching the remote repository.
- **Cleaner Git History:** Eliminates the need for "WIP: fix CI" commits.
- **Reproducibility:** Ensures that CI failures can be debugged interactively by reproducing the exact container state locally.
- **Resource Efficiency:** Colima is significantly lighter on system resources compared to Docker Desktop.

**Negative / Trade-offs:**
- **Environment Discrepancy:** Since we are proxying `macos-latest` to an Ubuntu container locally, OS-specific edge cases (e.g., BSD vs GNU coreutils, specific filesystem layouts) might behave differently locally than they do in the actual GitHub macOS runners.
- **Additional Tooling:** Developers must have `colima`, `docker`, and `act` installed (now codified in `Brewfile.home` and `Brewfile.work`).
