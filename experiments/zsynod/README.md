# zsynod — AI Collaborators Council (Experimental)

zsynod is an experimental multi-agent deliberation framework. It operates as an
isolated subsystem and is **not loaded by default** in zdots.

## Quick Start

To enable zsynod in your current shell session:

```bash
source experiments/enable-zsynod.sh
```

This will:
- Add `experiments/zsynod/bin/` to your `PATH`
- Set up the `ZSYNOD_DIR` environment variable
- Load zsynod completion functions
- Initialize zsynod metadata (members, ledger, etc.)

## Persistent Setup

To enable zsynod permanently:

1. **Option A: Shell profile**
   ```bash
   # Add to ~/.zshrc or appropriate shell init:
   source ~/.config/zsh/experiments/enable-zsynod.sh
   ```

2. **Option B: Alias for on-demand access**
   ```bash
   alias convene='source ~/.config/zsh/experiments/enable-zsynod.sh && zsynod convene'
   ```

## What Is zsynod?

zsynod implements **Raft-inspired consensus** for multi-agent deliberation:

- **Members**: AI agents (Claude, Pi, Aider, etc.) seated in `members.json`
- **Ledger**: Immutable hash-chained decision log (`ledger.jsonl`)
- **Voting**: Quorum-based decisions with rotating facilitator
- **Sessions**: Persistent forum state in `sessions/` and transcripts

See [CHARTER.md](CHARTER.md) for governance model, [STRATEGY.md](STRATEGY.md) for 
architecture, and [LIFECYCLE.md](LIFECYCLE.md) for session lifecycle.

## Usage

After enabling zsynod:

```bash
zsynod convene                    # Start a deliberation session
zsynod status                     # Check forum state and decisions
zsynod minutes                    # View formatted session minutes
zsynod queue                      # See pending proposals
zsynod propose <proposal>         # Submit a proposal for voting
zsynod launch <member>            # Launch an agent session
```

See `zsynod --help` for full command reference.

## Architecture

```
experiments/zsynod/
├── bin/zsynod                 # Main command
├── members.json              # Agent roster + seats
├── ledger.jsonl              # Immutable decision log
├── sessions/                 # Session state (durable)
├── transcripts/              # Agent session records
├── queue/                    # Proposal queue
├── minutes.md                # Formatted deliberation minutes
├── dials.json                # Quorum + timing config
├── functions/                # Zsh completion + utilities
├── TUTORIAL.md               # Usage walkthrough
├── CHARTER.md                # Governance model
├── STRATEGY.md               # System architecture
├── LIFECYCLE.md              # Session lifecycle
├── ZEN.md                    # Principles
└── DECISIONS.md              # Ratified decisions
```

## Design Principles

1. **Locality**: Forum state is self-contained in `experiments/zsynod/`
2. **Immutability**: Ledger is append-only; decisions are hash-chained
3. **Decoupling**: zsynod is independent from zdots core; can be removed or moved
4. **Testability**: Each session is reproducible from the ledger
5. **Observability**: All deliberation is auditable via minutes and transcripts

## Development

To move zsynod to a separate repository or experimental branch:

```bash
# Extract zsynod to a new branch (keeping history):
git subtree split --prefix experiments/zsynod -b zsynod-experimental

# Or, publish as a separate repo:
git subtree push --prefix experiments/zsynod <remote-url> main
```

## Troubleshooting

**zsynod command not found:**
```bash
source experiments/enable-zsynod.sh
```

**Members not loaded / decisions empty:**
- Check `members.json` exists and is valid JSON
- Verify `ZSYNOD_DIR` is set: `echo $ZSYNOD_DIR`

**Ledger corruption or sync issues:**
- Ledger is immutable; do not edit `ledger.jsonl` directly
- Use `zsynod` CLI commands to propose and ratify changes
- For cross-machine sync, use manual git pull + `zsynod status` to verify

**Experimental status**

zsynod is a work-in-progress exploration of multi-agent governance. It may:
- Change significantly in future iterations
- Be reorganized, moved to a separate repo, or removed entirely
- Require manual intervention if ledger structure changes

It is **not** a critical component of zdots.

## Questions?

See [STRATEGY.md](STRATEGY.md) for design rationale and [DECISIONS.md](DECISIONS.md) 
for ratified decisions on governance and architecture.
