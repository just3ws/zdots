# Autonomous Verification Experiment: Context Hydration

## Objective
Design a loop to autonomously verify that `pi-ctx-hydrate <tag>` returns the expected context structure and relevance for a given task, without human intervention.

## Experiment Design

### 1. The "Golden State" Definition
Create a JSON file in `sandbox/karpathy-method/golden_states/<tag>.json` that represents the expected output of `pi-ctx-hydrate <tag>`. This should include expected keys, minimum knowledge representation, and metadata requirements.

### 2. The Verification Loop (`verify.sh`)
A script that:
1.  Takes a `<tag>` as input.
2.  Runs `pi-ctx-hydrate <tag>` and captures the output.
3.  Compares the output against `golden_states/<tag>.json` using a semantic similarity tool (or a simple JSON structural check for MVP).
4.  Logs success/failure to `sandbox/karpathy-method/verification_results.log`.

### 3. Autonomy
This script can be triggered as a pre-commit hook or a scheduled task to ensure that our context definitions (the "Software 3.0 source code") don't drift.

## Next Action
1. Implement the structure for `golden_states/`.
2. Draft the `verify.sh` loop.
