# providers/ai/whisper-cpp.zsh — whisper.cpp implementation for local transcription
#
# This provider manages environment variables for whisper-ctl.

zdots_whisper_init() {
  export ZDOTS_WHISPER_PROFILE="${ZDOTS_WHISPER_PROFILE:-standard}"
  export ZDOTS_WHISPER_MODELS_DIR="${ZDOTS_WHISPER_MODELS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/whisper-cpp/models}"

  # Resolve configuration via metadata service
  local _meta_script="${ZDOTDIR:-$HOME/.config/zsh}/lib/metadata.bash"
  if [[ -f "$_meta_script" ]]; then
    eval "$(bash "$_meta_script" env whisper)"
  fi
}
