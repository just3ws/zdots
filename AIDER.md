# AIDER.md

Aider-specific instructions for Zdots.

**CRITICAL:** Read [AGENTS.md](AGENTS.md) first for the core architectural guidelines, performance standards, **RTK token-optimization rules**, and **PHI Operating Mode** (Section 8 — non-negotiable on work machines).

## Invocation

| Command | Purpose |
|---------|---------|
| `zaider` | Standard Aider session wired to local llama.cpp |
| `laid` | Low-priority Aider — nice +19, reduced threads, background edits |
| `zaider --hf` | **Opt-in** HuggingFace frontier lane (see below) |

Both `zaider` and `laid` auto-configure `AIDER_OPENAI_API_BASE` and `AIDER_OPENAI_API_KEY=local` to target `ZDOTS_AI_ENDPOINT`. No cloud keys required.

## Frontier (cloud) lane — `zaider --hf`

`zaider --hf` routes Aider to the **HuggingFace Inference Router** instead of the
local model. It is the opt-in counterpart to the local-only default; bare
`zaider` never touches the cloud. Gated by `lib/ai_cloud_lane.bash`:

- **Home-only.** Hard-refused when `ZDOTS_CONTEXT=work` (PHI boundary, exit 3).
- **Fail-closed.** Refuses unless `phi_scrub` is loadable. Key (`HF_TOKEN`) is
  read from the macOS Keychain only — never from a secrets file.
- **Honest scope.** `phi_scrub` cannot sit in the loop of an interactive agent.
  You are the last gate: do not type raw PHI/credentials into a cloud session.

Model defaults to `openai/Qwen/Qwen2.5-Coder-32B-Instruct`; override with
`ZDOTS_HF_MODEL`. Add the key once: `zdots-keychain add HF_TOKEN <value>`.

## Context Budget (7B model — 32k total)

| Slot | Tokens | Notes |
|------|--------|-------|
| System prompt | ~1k | Fixed |
| Repo map | ~2k | Controlled by `map-tokens: 2048` |
| Chat history | ~6k | Controlled by `max-chat-history-tokens` |
| File content | ~20k | What you get with `/add` |
| Output | ~2k | `n_predict` ceiling from llama.cpp |

**Be deliberate.** This is not a 200k-context model.

```
/add file.rb          # add only what you're editing
/drop file.rb         # free context when done
/clear                # wipe history between unrelated tasks
/tokens               # check budget before adding large files
```

## Platform Control

`zdots-ctl` is the single command for service orchestration.

```bash
zdots-ctl check       # deep health diagnostic — run first when something is wrong
zdots-ctl status      # live status of all services
zdots-ctl up          # start everything in dependency order
zdots-ctl down        # stop everything cleanly
```

## Database Access

The single database is `my` (PostgreSQL). All access uses role-based users — never connect as the OS superuser for routine work.

| User | Role | Purpose | Connect string |
|------|------|---------|----------------|
| `zdots_ro` | `zdots_reader` | Read-only exploration | `psql -U zdots_ro my` |
| `zdots_rw` | `zdots_writer` | App writes (zdots-ctx, context-engine) | `postgresql://zdots_rw@/my` |
| OS user | superuser | Migrations only — via `ZDOTS_MIGRATION_URL` | automatic via `zdots-ctx migrate` |

`ZDOTS_DATABASE_URL` always resolves to `postgresql://zdots_rw@/my`. Do **not** set `DATABASE_URL` — it has no owner here and causes confusion across tools.

For safe read-only exploration: `psql -U zdots_ro my`

## Workflow Notes

- Edit format is `architect` (plan/act) — the 7B model plans its own edits reliably with this pattern.
- Auto-commits are **off** — always review the diff before committing.
- Shell command suggestions are disabled — run linting and tests manually when you have headroom.
- Use `rtk` to reduce token pressure from high-output commands before `/add`ing output files.
