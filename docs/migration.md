# Migration Guide: Setting up a New Machine

This document provides a checklist and procedures for migrating your Zdots environment to a new macOS machine.

## 1. Pre-Migration (Old Machine)

Before you decommission your old machine, ensure you have the following data backed up or synced:

- **Secrets**: Copy your `.zdots.secrets` file to a secure location (e.g., a password manager or encrypted drive). **Do not commit this file.**
- **History**: If using Atuin, ensure your history is synced: `atuin sync`.
- **iTerm2**: Export your profile: `Preferences > Profiles > Other Actions > Export Profile`.
- **Local Assets**: If you have custom AI models or datasets in `~/.local/share/llama-cpp/models` that are not in the standard profiles, back them up.

## 2. Initial Setup (New Machine)

### Step 1: Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Setup GitHub Access
Generate a new SSH key and add it to your GitHub account to allow cloning the repository.
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
cat ~/.ssh/id_ed25519.pub | pbcopy
# Paste into GitHub Settings > SSH and GPG keys
```

### Step 3: Clone and Link
```bash
git clone git@github.com:just3ws/zdots.git ~/.config/zsh
ln -s ~/.config/zsh/.zshenv ~/.zshenv
source ~/.zshenv
```

## 3. Bootstrapping

Run the unified bootstrap command. This will install all Homebrew dependencies, hydrate AI models, and register services.

```bash
make bootstrap
```

### Manual Steps During Bootstrap:
- **Fonts**: The bootstrap installs `font-fira-code-nerd-font`. You must manually select **FiraCode Nerd Font** in your terminal's Profile settings to fix Powerlevel10k icons.
- **Secrets**: Create `~/.config/zsh/.zdots.secrets` by copying the example:
  ```bash
  cp ~/.config/zsh/.zdots.secrets.example ~/.config/zsh/.zdots.secrets
  # Edit and add your tokens
  vi ~/.config/zsh/.zdots.secrets
  ```
- **Runtimes**: Mise installs the manager, but you may need to install the actual runtimes:
  ```bash
  mise install
  ```

## 4. Verification

After bootstrapping, run the platform health check:

```bash
zdots-ctl status    # Verify services
zdots-ctl check     # Run full environment audit
```

## 5. Storage Hygiene

Once everything is running, remember to reclaim space periodically:
- `llama-ctl model-prune`
- `local-ci prune -f`
