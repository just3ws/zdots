---
name: zdots-omp
scope: zdots repository
audience: Oh-My-Pi (omp)
inherits: AGENTS.md
---

# Oh-My-Pi (`zomp`) & Multi-Account Loopback Gateway

Repository-wide policy is in [AGENTS.md](AGENTS.md). This file defines
Oh-My-Pi (`omp` / `zomp`) operation and multi-account model routing across Home
and Work environments.

## 1. Execution Lanes (`zomp`)

| Command | Posture | Routing | Allowed Context |
|---|---|---|---|
| `zomp` | Strictly Local | `default`, `smol`, `slow`, `plan` → `llamacpp/local` (`127.0.0.1:11500/v1`) with `--offline --no-judge --no-spotlight` | Home & Work (`ZDOTS_CONTEXT=work`) |
| `zomp --hybrid` | Hybrid Local + Frontier Multi-Account | `smol` → `llamacpp/local` ($0/zero quota burn); `default`/`plan`/`slow` → multi-account frontier pool with automatic `429` rollover (`etc/omp/config.home.yml`) | Home only (blocked on `ZDOTS_CONTEXT=work`) |
| `zomp --or` | Explicit OpenRouter + Local Smol | `smol` → `llamacpp/local`; `default` → `openrouter/$ZDOTS_OR_MODEL` | Home only (blocked on `ZDOTS_CONTEXT=work`) |
| `zomp --work-gateway` | Corporate Internal Gateway + Local Smol | `smol` → `llamacpp/local`; `default` → `$ZDOTS_WORK_AI_GATEWAY_URL` | Work (`ZDOTS_CONTEXT=work`) |

## 2. Multi-Account Loopback Broker & Gateway (`omp-gateway-ctl`)

`omp` includes a built-in SQLite credential vault (`omp auth-broker`) and an
OpenAI-compatible `/v1/chat/completions` router (`omp auth-gateway`) that load-balances
across multiple OAuth logins and API keys per provider (`google-gemini-cli`,
`openai-codex`, `github-copilot`, `openrouter`, `huggingface`, `llama.cpp`).

Manage the local loopback gateway (`127.0.0.1:11509` broker / `127.0.0.1:11510` gateway)
via `omp-gateway-ctl`:

```bash
omp-gateway-ctl status [--json]      # Check broker (11509) & gateway (11510) health
omp-gateway-ctl login [provider]     # Add an OAuth/API account to the active profile broker
omp-gateway-ctl import-keychain      # Sync Keychain keys into the Home broker (Home-only)
omp-gateway-ctl start                # Start loopback broker + OpenAI gateway on 127.0.0.1:11510
omp-gateway-ctl stop                 # Stop loopback broker + gateway
omp-gateway-ctl check [--strict]     # Probe account health and quota across all accounts
```

## 3. Home vs. Work Isolation Rules

- **Profile Isolation**: `zomp` isolates credentials and sessions per lane under
  `${XDG_STATE_HOME}/omp/profiles/zdots-{local,hybrid,or,work-gateway}`.
- **Work Machine Hard Boundary (`ZDOTS_CONTEXT=work`)**: `zdots_cloud_lane_guard`
  refuses `--hybrid`, `--or`, and `omp-gateway-ctl import-keychain`. Never import
  personal consumer accounts onto a work machine.
- **No AI Attribution**: Never add `Co-Authored-By:` or AI attribution lines to
  commits, PRs, code, or documentation.
