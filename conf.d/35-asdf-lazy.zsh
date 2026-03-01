_asdf_lazy_init() {
  local asdf_script="$HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh"
  if [[ ! -r "$asdf_script" ]]; then
    echo "asdf: initialization script not found at $asdf_script" >&2
    return 127
  fi

  unfunction asdf _asdf_lazy_init
  source "$asdf_script"
  command asdf "$@"
}

asdf() {
  _asdf_lazy_init "$@"
}
