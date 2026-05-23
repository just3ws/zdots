# env.sh — POSIX-compatible environment core
# This file is sourced by sh, bash, and zsh.

# 0. Security Baseline
# Ensure files and directories created by the shell are user-only by default.
umask 077

# 1. Dependency Manifest (Composition Root)
# Load environment baseline configuration if it exists.
if [ -f "${ZDOTDIR:-$HOME/.config/zsh}/.zdots.env" ]; then
  . "${ZDOTDIR:-$HOME/.config/zsh}/.zdots.env"
fi

# 1b. Secrets — macOS Keychain is the primary source; .zdots.secrets is a fallback.
# On darwin: lib/keychain.bash is sourced and zdots_keychain_load populates all
# known vars. Keychain is loaded AFTER the file so Keychain values always win.
# On non-darwin: only the file path is used (Linux dev machines).
# To add a secret: zdots-keychain add VARNAME value
# To migrate from file:  zdots-keychain migrate
_zdots_secrets="${ZDOTDIR:-$HOME/.config/zsh}/.zdots.secrets"
_zdots_kc_lib="${ZDOTDIR:-$HOME/.config/zsh}/lib/keychain.bash"
if [ -f "$_zdots_secrets" ]; then
  . "$_zdots_secrets"
fi
if [ "$(uname -s 2>/dev/null)" = "Darwin" ] && [ -f "$_zdots_kc_lib" ]; then
  . "$_zdots_kc_lib"
  zdots_keychain_load \
    ZDOTS_DB_ENCRYPTION_KEY \
    MAXMIND_ACCOUNT_ID MAXMIND_LICENSE_KEY MAXMIND_EDITION_IDS \
    HUGGINGFACE_TOKEN \
    HOMEBREW_GITHUB_API_TOKEN GITHUB_TOKEN MISE_GITHUB_TOKEN \
    ANTHROPIC_API_KEY OPENAI_API_KEY
fi
unset _zdots_secrets _zdots_kc_lib

# 1c. Machine-local overrides (Ignored by Git)
# Machine identity, context (work/home), and per-machine overrides.
# Copy from .zdots.local.example and fill in. Never commit this file.
if [ -f "${ZDOTDIR:-$HOME/.config/zsh}/.zdots.local" ]; then
  . "${ZDOTDIR:-$HOME/.config/zsh}/.zdots.local"
fi

# 1d. Work profile — sourced AFTER .zdots.local so enforced values win.
# Activated by setting ZDOTS_CONTEXT=work in .zdots.local.
if [ "${ZDOTS_CONTEXT:-home}" = "work" ] && [ -f "${ZDOTDIR:-$HOME/.config/zsh}/.zdots.work" ]; then
  . "${ZDOTDIR:-$HOME/.config/zsh}/.zdots.work"
fi

# 2. XDG Base Directory Specification (Harden & Absolute)
export XDG_ROOT="$HOME"
export XDG_CONFIG_HOME="$XDG_ROOT/.config"
export XDG_STATE_HOME="$XDG_ROOT/.local/state"
export XDG_CACHE_HOME="$XDG_ROOT/.cache"
export XDG_DATA_HOME="$XDG_ROOT/.local/share"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# 3. Session & Trace Identification (W3C Trace Context)
# Unique ID for the life of this shell session (W3C Trace ID: 32 hex chars).
if [ -z "${ZDOTS_TRACE_ID:-}" ]; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh: printf -v is a builtin — no fork. 8x $RANDOM = 128-bit entropy.
    printf -v ZDOTS_TRACE_ID '%04x%04x%04x%04x%04x%04x%04x%04x' \
      $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM
    export ZDOTS_TRACE_ID
  elif command -v openssl >/dev/null 2>&1; then
    export ZDOTS_TRACE_ID="$(openssl rand -hex 16)"
  else
    # Fallback to a timestamp + PID if openssl is missing.
    export ZDOTS_TRACE_ID="$(date +%s%N | cksum | awk '{print $1}')-$(printf "%x" $$ | xargs printf "%016s" | tr ' ' '0')"
  fi
fi

# Initial Span ID for the shell process (W3C Parent ID: 16 hex chars).
if [ -z "${ZDOTS_SPAN_ID:-}" ]; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh: printf -v is a builtin — no fork. 4x $RANDOM = 64-bit entropy.
    printf -v ZDOTS_SPAN_ID '%04x%04x%04x%04x' $RANDOM $RANDOM $RANDOM $RANDOM
    export ZDOTS_SPAN_ID
  elif command -v openssl >/dev/null 2>&1; then
    export ZDOTS_SPAN_ID="$(openssl rand -hex 8)"
  else
    export ZDOTS_SPAN_ID="$(printf "%x" $$ | xargs printf "%016s" | tr ' ' '0')"
  fi
fi

# W3C Traceparent: 00-${ZDOTS_TRACE_ID}-${ZDOTS_SPAN_ID}-01 (01 = sampled)
export TRACEPARENT="00-${ZDOTS_TRACE_ID}-${ZDOTS_SPAN_ID}-01"
export ZDOTS_SESSION_ID="${ZDOTS_TRACE_ID}"

# 4. Observability Utilities (Core)
# zdots_trace_redact DATA
# Returns redacted data masking common secrets AND PHI patterns. (POSIX-compatible via sed fallback)
# Patterns covered:
#   - Flag-based secrets:  --password, --api-key, --token, --secret, --auth, --authorization
#   - PHI: SSN (NNN-NN-NNNN), MRN labels, DOB labels, DB connection strings with credentials
zdots_trace_redact() {
  local data="$1"

  # Apply via sed (single pass, POSIX-compatible). Used for both Zsh and non-Zsh contexts.
  # sed is available on every supported platform; this avoids the Zsh-only glob path while
  # still covering all PHI patterns consistently.
  echo "$data" | sed -E \
    -e 's/(-p|--password|--api-key|--token|--secret|--auth|--authorization)[[:space:]:]+[^[:space:]]+/\1 [REDACTED]/g' \
    -e 's/[0-9]{3}-[0-9]{2}-[0-9]{4}/[REDACTED-SSN]/g' \
    -e 's/MRN[[:space:]]*:?[[:space:]]*[0-9]+/[REDACTED-MRN]/g' \
    -e 's/(DOB|[Dd]ate[[:space:]]+[Oo]f[[:space:]]+[Bb]irth)[[:space:]]*:?[[:space:]]*[0-9]{1,2}[/\-][0-9]{1,2}[/\-][0-9]{2,4}/[REDACTED-DOB]/g' \
    -e 's;(postgresql|mysql|redis)://[^@[:space:]]+@[^/[:space:]]*;[REDACTED-CONN];g'
}

# 5. Dependency Injection (DI) Helper
# Loads a service provider implementation.
zdots_require() {
  local service_type="$1"
  local provider="$2"
  local provider_file="${ZDOTDIR}/providers/${service_type}/${provider}.zsh"

  if [ -r "$provider_file" ]; then
    zdots_safe_source "$provider_file"
  fi
}

# 5. Circuit Breaker (The Submarine Standard)
# Safely sources a file, catching errors and preventing shell collapse.
zdots_safe_source() {
  local file="$1"
  if [ ! -r "$file" ]; then
    return 1
  fi

  # Attempt to source in a subshell-like protected way if possible,
  # but for standard POSIX env.sh we just source directly and rely 
  # on 'set +e' to prevent collapse.
  if . "$file"; then
    return 0
  else
    local status=$?
    echo "zdots: warning: failed to source $file (exit $status)" >&2
    if [ -n "$(command -v zdots_trace_log)" ]; then
      zdots_trace_log "error" "source_failure=$file, status=$status"
    fi
    return $status
  fi
}

# 5b. Provider Timeout Protection
# Wraps external commands with a timeout to prevent shell startup from hanging.
# Uses timeout/gtimeout when available; falls back to running without timeout.
ZDOTS_PROVIDER_TIMEOUT="${ZDOTS_PROVIDER_TIMEOUT:-3}"

zdots_cmd_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$ZDOTS_PROVIDER_TIMEOUT" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$ZDOTS_PROVIDER_TIMEOUT" "$@"
  else
    "$@"
  fi
}

# Load configured service implementations
zdots_require pkg "${ZDOTS_SERVICE_PKG_MANAGER:-none}"
zdots_require node "${ZDOTS_SERVICE_NODE_RUNTIME:-system}"
zdots_require trace "${ZDOTS_SERVICE_TRACE:-none}"
zdots_require ai "${ZDOTS_SERVICE_AI:-none}"
zdots_require whisper "${ZDOTS_SERVICE_WHISPER:-none}"

# 4. XDG Tool Overrides (Force compliance for standard tools)
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"
export BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME/bundle/config"
export BUNDLE_USER_CACHE="$XDG_CACHE_HOME/bundle"
export BUNDLE_USER_PLUGIN="$XDG_DATA_HOME/bundle"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node/repl_history"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export PSQL_HISTORY="$XDG_STATE_HOME/psql/history"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"

# 5. General Environment
export OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318"
OTEL_SERVICE_NAME="zdots-shell"   # intentionally not exported — must not bleed into child processes
export LANG='en_US.UTF-8'
export EDITOR='vi'
export VISUAL="$EDITOR"
export PGPASSFILE="$XDG_CONFIG_HOME/pgpass"
export DOCKER_CLI_HINTS=false
export ENABLE_LSP_TOOL=1
export ZDOTS_THEME="${ZDOTS_THEME:-dracula-pro}"

# 6. Language-Specific XDG Alignment
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export GOPATH="$XDG_DATA_HOME/go"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export BUN_INSTALL="$HOME/.bun"

# 7. Homebrew Core Detection (Legacy Fallback/Overridable)
if [ -z "${HOMEBREW_PREFIX:-}" ] && [ "$ZDOTS_ENV_PROFILE" != "ci-act" ]; then
  if [ -d /opt/homebrew ]; then
    export HOMEBREW_PREFIX=/opt/homebrew
  elif [ -d /usr/local ]; then
    export HOMEBREW_PREFIX=/usr/local
  fi
fi

if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  export HOMEBREW_CASK_OPTS='--appdir=/Applications'
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_INSECURE_REDIRECT=1
  export HOMEBREW_BUNDLE_FILE="$ZDOTDIR/Brewfile"
  export HOMEBREW_BAT=1

  if [ -x "$HOMEBREW_PREFIX/bin/nvim" ]; then
    export EDITOR="$HOMEBREW_PREFIX/bin/nvim"
    export VISUAL="$EDITOR"
  fi
fi

# 8. OpenJDK Configuration
if [ -d "$HOMEBREW_PREFIX/opt/openjdk" ]; then
  export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi

# 9. Path Construction (SOLID & Decoupled)
# Helper to append to PATH if directory exists and is not already present.
_zdots_path_add() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) [ -d "$1" ] && PATH="$1:$PATH" ;;
  esac
}

# Core system paths first (to ensure basic tools are available)
PATH="/usr/bin:/bin:/usr/sbin:/sbin"

# 9a. Legacy/Explicit Overrides (Lower precedence than Service Providers)
if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  _zdots_path_add "$HOMEBREW_PREFIX/bin"
  _zdots_path_add "$HOMEBREW_PREFIX/sbin"
  _zdots_path_add "$HOMEBREW_PREFIX/opt/openjdk/bin"
  _zdots_path_add "$HOMEBREW_PREFIX/opt/postgresql@18/bin"
  _zdots_path_add "$HOMEBREW_PREFIX/opt/rustup/bin"
fi
_zdots_path_add "$CARGO_HOME/bin"
_zdots_path_add "$GOPATH/bin"
_zdots_path_add "$PNPM_HOME"
_zdots_path_add "$BUN_INSTALL/bin"
_zdots_path_add "$HOME/.lmstudio/bin"

# 9b. Service-based Path Setup (Dependency Injection)
# We call provider-specific path functions if they were defined by zdots_require.
# These have HIGHER precedence than legacy overrides.
if [ -n "$(command -v zdots_pkg_manager_paths)" ]; then
  zdots_pkg_manager_paths
fi
if [ -n "$(command -v zdots_node_runtime_paths)" ]; then
  zdots_node_runtime_paths
fi

# 9c. User Binaries (Highest precedence)
_zdots_path_add "$ZDOTDIR/bin"
_zdots_path_add "$HOME/.local/bin"
_zdots_path_add "$HOME/.antigravity/antigravity/bin"

export PATH
unset -f _zdots_path_add

# 10. History (XDG Compliance: Move to STATE_HOME)
export HISTSIZE=999999
export HISTFILE="$XDG_STATE_HOME/zsh/history"
