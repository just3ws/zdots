#!/usr/bin/env bash
# lib/sdk/docker-host.bash — Tenant CLI SDK: Colima/Docker socket resolution (Z-185, ADR-0005).
#
# Delegates to `colima-status socket` so downstream tenants never hardcode
# ~/.colima/default/docker.sock or ~/.config/colima/default/docker.sock.
#
# Usage:
#   source "${ZDOTDIR:-$HOME/.config/zsh}/lib/sdk/docker-host.bash"
#   DOCKER_HOST="$(zdots_docker_host)"
#   # or:
#   zdots_export_docker_host

zdots_docker_host() {
  if [ -n "${DOCKER_HOST:-}" ]; then
    printf '%s\n' "$DOCKER_HOST"
    return 0
  fi
  local bin="${ZDOTDIR:-$HOME/.config/zsh}/bin/colima-status"
  if ! [ -x "$bin" ]; then
    bin="$(command -v colima-status 2>/dev/null || true)"
  fi
  if [ -z "$bin" ]; then
    printf 'zdots_docker_host: colima-status not found\n' >&2
    return 1
  fi
  local sock
  sock="$("$bin" socket 2>/dev/null)" || return 1
  [ -n "$sock" ] || return 1
  printf 'unix://%s\n' "$sock"
}

zdots_export_docker_host() {
  local h
  h="$(zdots_docker_host)" || return 1
  export DOCKER_HOST="$h"
}
