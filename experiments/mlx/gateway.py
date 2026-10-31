import sys
import json
import os

# Keep this experiment self-contained; its implementation is archived beside it.
EXPERIMENT_PATH = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, EXPERIMENT_PATH)

from mlx_engine import get_engine
from karpathy_method.bin.context_compact import compact

# Budget constraint (1024 tokens)
MAX_TOKENS = 1024

def run_atomic_turn(system_prompt, user_prompt, engine_provider='mlx'):
    # 1. Compact context before it even touches the engine
    compacted_context = compact({
        "system": system_prompt,
        "history": [{"role": "user", "content": user_prompt}]
    })
    
    # 2. Extract compacted prompts
    data = json.loads(compacted_context)
    
    # 3. Inference
    engine = get_engine('local', provider=engine_provider)
    return engine.generate_completion(data['system'], data['history'][0]['content'], max_tokens=MAX_TOKENS)
