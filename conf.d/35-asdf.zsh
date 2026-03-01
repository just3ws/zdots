# Initialize asdf when available.
_asdf_scripts=(
  "$HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh"
  "$HOME/.asdf/asdf.sh"
)

for _asdf_script in $_asdf_scripts; do
  if [[ -r "$_asdf_script" ]]; then
    source "$_asdf_script"
    break
  fi
done

unset _asdf_script _asdf_scripts
