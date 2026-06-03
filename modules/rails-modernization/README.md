# Rails Modernization Module

Optional tooling for build-only legacy Rails analysis. This module is not part
of the core zdots command surface.

## Install Dependencies

```bash
brew bundle --file modules/rails-modernization/Brewfile
```

## Commands

Run these from a target Rails project root:

```bash
modules/rails-modernization/bin/zdots-ruby-legacy-setup
modules/rails-modernization/bin/zdots-archeologist User
modules/rails-modernization/bin/zdots-archeologist-run git@github.com:org/repo.git User
```

To use the commands by short name for one shell session:

```bash
export PATH="$ZDOTDIR/modules/rails-modernization/bin:$PATH"
```
