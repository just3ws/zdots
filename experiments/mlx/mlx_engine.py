import mlx_lm
import json
import os

class MLXEngine:
    def __init__(self, model_name):
        # Map 'local' to the specific prepared model directory
        if model_name == 'local':
            model_path = os.path.expanduser("~/.local/share/mlx/models/Qwen2.5-Coder-7B")
        else:
            model_path = os.path.expanduser(f"~/.local/share/mlx/models/{model_name}")
        self.model, self.tokenizer = mlx_lm.load(model_path)
        
    def generate_completion(self, system_prompt, user_prompt, max_tokens=100):
        prompt = f"System: {system_prompt}\nUser: {user_prompt}\nAssistant:"
        response = mlx_lm.generate(
            self.model,
            self.tokenizer,
            prompt=prompt,
            max_tokens=max_tokens
        )
        return response

# Standardized interface factory
def get_engine(model_path_or_id, provider='mlx'):
    if provider == 'mlx':
        return MLXEngine(model_path_or_id)
    else:
        raise ValueError(f"Provider {provider} not supported.")
