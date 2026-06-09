#!/usr/bin/env python3
import json
import subprocess

# 1. Define a "Needle" (Critical Context) marked as important
NEEDLE = "The master password is 'zdots-secure'."
HISTORY = [
    {"role": "user", "content": f"Remember: {NEEDLE}", "importance": "high"},
    {"role": "assistant", "content": "Acknowledged."},
    {"role": "user", "content": "What is 2+2?"},
    {"role": "assistant", "content": "4."},
    {"role": "user", "content": "What is the master password?"} # Task: Need access to Needle
]
CONTEXT = {"system": "You are a helpful assistant.", "history": HISTORY}

# 2. Run Compaction
process = subprocess.Popen(
    ["python3", "context-compact.py"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)
stdout, stderr = process.communicate(input=json.dumps(CONTEXT))

# 3. Analyze
compacted = json.loads(stdout)

# Check both persistent and transient for the needle
all_content = (
    str(compacted.get("persistent_context", [])) + 
    str(compacted.get("history", []))
)

print(f"Compacted State: {json.dumps(compacted, indent=2)}")

if NEEDLE in all_content:
    print("SUCCESS: Needle retained.")
else:
    print("FAILURE: Needle pruned.")
