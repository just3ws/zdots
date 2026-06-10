import mlx_lm
import json
import os

class MLXEngine:
    def __init__(self, model_path_or_id):
        self.model, self.tokenizer = mlx_lm.load(model_path_or_id)
        
    def generate_completion(self, system_prompt, user_prompt, max_tokens=100, temperature=0.7):
        prompt = f"System: {system_prompt}\nUser: {user_prompt}\nAssistant:"
        response = mlx_lm.generate(
            self.model,
            self.tokenizer,
            prompt=prompt,
            max_tokens=max_tokens,
            temp=temperature
        )
        return response

# Standardized interface factory
def get_engine(model_path_or_id, provider='mlx'):
    if provider == 'mlx':
        return MLXEngine(model_path_or_id)
    else:
        raise ValueError(f"Provider {provider} not supported.")
