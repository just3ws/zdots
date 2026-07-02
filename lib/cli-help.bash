#!/usr/bin/env bash
# lib/cli-help.bash — shared -h/--help detection for bin/ command dispatchers.
#
# Z-182 established that destructive subcommands must short-circuit to usage()
# BEFORE any side effect when invoked with -h/--help. The detection logic was
# inlined across ~10 commands in five different shapes (scan-all-args loops, a
# local _wants_help(), per-subcommand case arms). These predicates are the
# single source of truth for "do these args request help?".
#
# Deliberately pure: each call site keeps its own usage(), its own exit vs
# return, and any unknown-flag rejection with per-command error text — so the
# exact Z-182 semantics are preserved. The predicate never calls usage or exits.
#
# Usage (source after `set -euo pipefail`):
#   source "${ZDOTDIR}/lib/cli-help.bash"
#
#   zdots_cli_wants_help "$@"        && { usage; exit 0; }     # top-level scan
#   zdots_cli_wants_help "${1:-}"    && { usage; return 0; }   # inside a cmd_*
#   zdots_cli_wants_help_strict "$@" && { usage; exit 0; }     # destructive subcmd

# Returns 0 if any argument is exactly -h or --help.
zdots_cli_wants_help() {
  local _a
  for _a in "$@"; do
    case "$_a" in
      -h|--help) return 0 ;;
    esac
  done
  return 1
}

# Stricter variant for destructive subcommands that also accept bare-value args
# (e.g. a filename to transcribe): -h/--help OR any other leading flag (-*) seen
# before a `--` terminator counts as "show usage". Bare values pass through.
zdots_cli_wants_help_strict() {
  local _a
  for _a in "$@"; do
    case "$_a" in
      -h|--help) return 0 ;;
      --)        return 1 ;;
      -*)        return 0 ;;
    esac
  done
  return 1
}
