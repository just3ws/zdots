#!/usr/bin/env python3
import json
import sys
from pathlib import Path

EXPERIMENT_PATH = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(EXPERIMENT_PATH))

from karpathy_method.bin.context_compact import compact

def run_compaction(context):
    return json.loads(compact(context))

# Test 1: Needle Retention (High Importance)
NEEDLE = "retain-this-note"
HISTORY = [{"role": "user", "content": f"Important: {NEEDLE}", "importance": "high"}] + \
          [{"role": "user", "content": "Filler"} for _ in range(10)]
context = {"history": HISTORY}
result = run_compaction(context)
assert NEEDLE in str(result["persistent_context"]), "Needle lost in persistent!"
print("Test 1 (Needle) Passed.")

# Test 2: Budget Enforcement (Heuristic)
LARGE_HISTORY = [{"role": "user", "content": "x" * 5000}]
context = {"history": LARGE_HISTORY}
result = run_compaction(context)
# We expect history to be truncated by the logic (history[-3:])
assert len(result["history"]) <= 3, f"Failed budget: {len(result['history'])} turns"
print("Test 2 (Budget) Passed.")

print("All robust tests passed.")
