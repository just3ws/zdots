#!/usr/bin/env python3
import json
import sys

def compact(context):
    """
    Improved compaction strategy:
    1. Retain L1 (System Prompt) and L2 (Persistent Context).
    2. Promote turns marked 'importance: high' to L2.
    3. Truncate L3 (Transient history) to the last 3 turns.
    """
    # Initialize L2 persistent storage
    persistent = context.get("persistent_context", [])
    
    # Process history: split into transient and persistent
    new_transient = []
    for turn in context.get("history", []):
        if turn.get("importance") == "high":
            if turn not in persistent:
                persistent.append(turn)
        else:
            new_transient.append(turn)
            
    # Keep only last 3 transient turns
    compacted = {
        "system": context.get("system", ""),
        "persistent_context": persistent,
        "history": new_transient[-3:]
    }
    
    return json.dumps(compacted)

if __name__ == "__main__":
    try:
        input_data = json.load(sys.stdin)
        output = compact(input_data)
        print(output)
    except Exception as e:
        sys.stderr.write(f"Error compacting: {e}\n")
        sys.exit(1)
