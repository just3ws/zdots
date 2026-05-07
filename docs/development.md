# Local Development & Setup

This guide covers the local setup, bootstrapping, and common development workflows for the Zdots platform.

## 1. Prerequisites

- **OS:** macOS (Apple Silicon M-series recommended for AI features).
- **Tooling:** Homebrew, Zsh.

## 2. Installation

To install Zdots as your primary Zsh configuration:

```sh
cd
mv -f .zshenv .zshenv.bak
git clone git@github.com:just3ws/zdots.git ~/.config/zsh
ln -s ~/.config/zsh/.zshenv ~/.zshenv
exec "$SHELL"
```

## 3. Bootstrapping

Once the shell is loaded, run the bootstrap command to install all dependencies and hydrate the AI models.

```sh
make bootstrap
```

This command handles:
1. `brew bundle` — installs all required packages (llama.cpp, OTel, etc.).
2. AI hydration — downloads the default Qwen model (~4.7GB).
3. Service registration — registers `launchd` plists for background services.

## 4. Platform Control

Use `zdots-ctl` to manage the lifecycle of all services in dependency order.

```sh
zdots-ctl up      # Start everything (Colima, OTel, AI)
zdots-ctl down    # Stop everything
zdots-ctl status  # Check health
```

## 5. Development Workflows

### Modifying Configuration
- Edit `.zdots.env` to swap service providers.
- Edit `etc/ai-models.yaml` to change model parameters.
- Always run `llama-ctl install` after modifying AI configs to apply changes.

### Adding New Tools
- Standalone scripts go in `bin/`.
- Interactive shell modules go in `conf.d/*.zsh`.
- Shared logic goes in `lib/`.

### Debugging
- **Logs:** Use `llama-ctl logs` or `otel-collector logs`.
- **Diagnostics:** Run `zdots-ctl check` for a comprehensive environment audit.
- **Circuit Breaker:** If a module is crashing the shell, `ZDOTS_SAFE_MODE=1` will bypass all `conf.d/` modules.

## 6. Storage Hygiene

Since AI models and Docker containers consume significant disk space:
- Run `llama-ctl model-prune` to remove unused models.
- Run `docker-reclaim` to free up Colima/Docker disk space.
