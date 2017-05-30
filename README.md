# Zdots

My Zsh dotfiles.

## Installation

```shell
mv -f .zshenv .zshenv.bak
mkdir -p ~/.local/share/zsh
cd
git clone git@github.com:just3ws/zdots.git ~/.config/zsh`
ln ~/.config/zsh/.zshenv
exec "$SHELL"
```
