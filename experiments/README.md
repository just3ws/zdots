# Experiments

This directory contains **experimental** features that are decoupled from zdots core.
They can be optionally loaded, moved to separate repositories, or removed without
affecting the main system.

## Philosophy

Experimental features:
- Are **not loaded by default** in shell initialization
- Have **zero hard dependencies** from core zdots
- Can be **extracted to a separate repository** or branch without code changes
- Should be **self-documenting** with clear initialization instructions

## Current Experiments

### zsynod — AI Collaborators Council

Multi-agent deliberation framework for consensus-driven decision making.

**Status**: Working prototype  
**Enable**: `source experiments/enable-zsynod.sh`  
**Docs**: See [zsynod/README.md](zsynod/README.md)

---

## Adding a New Experiment

1. Create a subdirectory: `experiments/my-experiment/`
2. Include a `README.md` with:
   - One-line description
   - Initialization instructions
   - Architecture overview
   - Design principles
3. Create an `enable-my-experiment.sh` script that:
   - Sets environment variables
   - Adds binaries to PATH
   - Initializes state if needed
4. **Do not** reference the experiment from core zdots files
5. All cross-module imports go through the enable script, not auto-sourcing

## Extracting an Experiment

To move an experiment to a separate repository:

```bash
# Create a new repo with just this experiment's history
git subtree split --prefix experiments/my-experiment -b my-experiment-split

# Push to a new repository
git subtree push --prefix experiments/my-experiment <new-repo-url> main

# Or, remove the experiment entirely
git rm -r experiments/my-experiment/
```

## Design Constraints

Experiments **must not**:
- Be sourced automatically in `conf.d/`, `lib/`, or shell init files
- Add environment variables to the shell's global state without explicit opt-in
- Register commands in the main PATH via default initialization
- Reference zsh builtins or system paths that might not exist on other machines
- Depend on secrets in Keychain without explicit setup docs

Experiments **should**:
- Include a `README.md` with clear initialization steps
- Provide an `enable-*.sh` script for one-line setup
- Be self-contained in their directory
- Document how to disable or remove them
- State their "experimental" status clearly
