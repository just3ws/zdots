---
id: tutorial-zdots-onboarding
title: "Tutorial: Zdots Onboarding and Capability Map"
purpose: End-to-end introduction to the core control plane, modules, tools, services, dependencies, and common workflows.
---

# Tutorial: Zdots Onboarding and Capability Map

This tutorial is the shortest path from a fresh clone to a working mental model of zdots.
It covers the core platform, the main tools, the services they depend on, and the commands
used for setup and day-to-day use.

## 1. What Zdots Is

Zdots is a shell configuration plus a local control plane.

- `bin/` contains the operator-facing commands.
- `lib/` contains shared shell libraries and boundary logic.
- `conf.d/` contains shell hooks and runtime behavior.
- `docs/` explains the platform, workflows, and operating rules.
- `tests/` verifies the CLI contracts and key integration paths.

The important idea is that zdots is not just aliases and prompt code. It includes:

- local AI
- observability
- PostgreSQL-backed knowledge storage
- service lifecycle management
- key and secret handling
- task hydration and trace propagation

## 2. First Orientation

Start every new session with these commands:

```bash
zdots-ctl status
capabilities --json
agent-guide
```

Use them in this order:

1. `zdots-ctl status` tells you whether the platform services are up.
2. `capabilities --json` tells you what the machine can actually do.
3. `agent-guide` gives the live endpoint and service map for agents.

If the machine is unhealthy, stop there and fix the failing service first.

## 3. Core Services

These are the major services and what they provide.

| Service | Purpose | Typical commands |
|---|---|---|
| `zdots-ctl` | Top-level orchestrator | `up`, `down`, `check`, `status`, `install` |
| `zsvc` | Service registry and health/log view | `list`, `health`, `logs`, `diag`, `restart` |
| `llama-ctl` | Local chat model manager | `status`, `start`, `stop`, `install`, `model-download` |
| `otel-collector` | Host-side trace collector | `status`, `start`, `stop`, `logs` |
| `local-ci` | Containerized LGTM stack | `up`, `down`, `logs`, `health` |
| `zdots-ctx` | PostgreSQL brain and knowledge layer | `query`, `capture`, `hydrate`, `migrate` |
| `zdots-keychain` | macOS Keychain secret store | `add`, `get`, `list`, `verify` |
| `zdots-github-keys` | GitHub SSH setup and rotation | `plan`, `apply`, `rotate-stage`, `rotate-promote` |
| `zdots-ask` | Domain-aware local AI router | shell, ruby, phi, default prompt routing |
| `zdots-quiz` | Local model smoke test | quick capability probe |
| `ztask` | Task hydration and tracking | `start`, `done`, `stop`, `status` |

## 4. Dependency Map

Use this mental model when deciding what depends on what.

| Layer | Depends on | Notes |
|---|---|---|
| Shell runtime | `conf.d/`, `lib/`, `env.sh` | Loads the control plane into each shell session |
| AI routing | `zdots-ask`, `ai-query`, `llama-ctl` | Local inference only unless explicitly reviewed otherwise |
| Observability | `otel-collector`, `local-ci`, `zsvc` | Traces and logs are collected locally first |
| Knowledge | `zdots-ctx`, PostgreSQL `my` | Stores lessons, methodologies, and session residue |
| Secrets | `zdots-keychain`, Keychain | Secrets must not live in tracked plaintext files |
| GitHub SSH | `github-keygen`, `zdots-github-keys` | Generates dedicated home/work identities and aliases |

The practical rule is simple:

- If you need service health, start with `zdots-ctl` or `zsvc`.
- If you need AI, use `zdots-ask` or `ai-query`, not raw model endpoints.
- If you need state, use `zdots-ctx` and the `my` database.
- If you need secrets, use `zdots-keychain`.

## 5. Fresh Machine Setup

On a new machine, follow the authoritative setup path:

```bash
git clone <your-remote> ~/.config/zsh
cd ~/.config/zsh
bin/bootstrap
```

Before bootstrap on a work machine, create `.zdots.local` and set the machine context:

```bash
cp .zdots.local.example .zdots.local
$EDITOR .zdots.local
```

Set at least:

```bash
ZDOTS_CONTEXT=work
```

Then complete the machine bootstrap and verify the result:

```bash
zdots-ctl status
zdots-ctl check
```

If the machine touches PHI, finish the Keychain and posture steps from `SETUP.md` before using AI tooling.

## 6. Secrets and Identity

Use the platform tools for credentials and GitHub identities.

```bash
zdots-keychain add SOME_SECRET value
zdots-keychain verify
```

For GitHub SSH, use the explicit home/work workflow:

```bash
zdots-github-keys plan \
  --home-user HOME_GITHUB_USER \
  --work-user WORK_GITHUB_USER \
  --default home
```

That tutorial lives in [docs/TUTORIAL_GITHUB_SSH_KEYS.md](TUTORIAL_GITHUB_SSH_KEYS.md).

## 7. Daily Workflow

The common daily loop is:

1. Check service health.
2. Hydrate task context if work is task-driven.
3. Query the brain for prior lessons.
4. Use the AI router for shell or Ruby work.
5. Capture anything reusable back into the knowledge layer.

Concrete commands:

```bash
zdots-ctl status
ztask start Z-123 "Investigate shell startup regression"
zdots-ctx query "similar startup regressions"
zdots-ask --domain shell "analyze this zsh startup hook"
zdots-ctx capture
ztask done Z-123
```

## 8. Service Workflows

### Local AI

Use the local AI tools for inference and capability checks.

```bash
llama-ctl status
zdots-ask "explain this shell function"
zdots-quiz --quick
```

### Observability

Use the collector and service registry to inspect the local telemetry path.

```bash
otel-collector status
zsvc health
zsvc logs all
```

### Knowledge Layer

Use the brain for durable context and methodology storage.

```bash
zdots-ctx query "credential rotation"
zdots-ctx hydrate
zdots-ctx status
```

## 9. Modules

The core repo also ships optional modules. The main one today is the Rails modernization module under `modules/rails-modernization/`.
It is separate from the core command surface and is used for read-only legacy Rails analysis and Bundler setup.

Use it when you need to inspect or ingest a legacy Rails app:

```bash
brew bundle --file modules/rails-modernization/Brewfile
modules/rails-modernization/bin/zdots-ruby-legacy-setup
modules/rails-modernization/bin/zdots-archeologist-run git@github.com:org/repo.git User
```

For a one-shell-session short-name workflow:

```bash
export PATH="$ZDOTDIR/modules/rails-modernization/bin:$PATH"
```

The module README lives at [modules/rails-modernization/README.md](../modules/rails-modernization/README.md).

## 10. When To Use Which Tool

| Situation | Use |
|---|---|
| Check if the machine is ready | `zdots-ctl status` |
| Validate the machine contract | `capabilities --json` |
| Inspect all services | `agent-guide` or `zsvc health` |
| Work with local AI | `zdots-ask` or `ai-query` |
| Remember prior lessons | `zdots-ctx query` |
| Store a secret | `zdots-keychain` |
| Rotate GitHub SSH keys | `zdots-github-keys` |
| Start a tracked task | `ztask start` |

## 11. Recovery Rule

If a command or service behaves differently from the docs or its `--help`, do not patch zdots blindly.
File a `zdots-issue` and stop at the task boundary.

That keeps the platform stable for the next operator and preserves the contract for hidden callers.
