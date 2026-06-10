import mlx_lm
import inspect

print("Checking mlx_lm.load:")
print(inspect.signature(mlx_lm.load))
print("\nChecking mlx_lm.generate:")
print(inspect.signature(mlx_lm.generate))
