if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export _ZDOTS_BREW_SHELLENV=1
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
  export _ZDOTS_BREW_SHELLENV=1
fi

# Keep asdf shims first so login shells resolve Ruby/Bundler via asdf, not /usr/bin.
if [[ -d "$HOME/.asdf/shims" ]]; then
  path=("$HOME/.asdf/shims" $path)
fi
if [[ -d "$HOME/.asdf/bin" ]]; then
  path=("$HOME/.asdf/bin" $path)
fi
typeset -gU path
