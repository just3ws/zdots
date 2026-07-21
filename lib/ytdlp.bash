# lib/ytdlp.bash — yt-dlp cookie strategy (Z-237)
#
# Bot-gated sites (notably YouTube) reject anonymous fetches with
# "Sign in to confirm you're not a bot", which fails ingest at both the metadata
# dump (bin/zdots-ingest-media) and the audio download (recipes/yt-transcribe).
# Supply cookies via one of two OPT-IN env knobs; the default is no cookies —
# unchanged behaviour, still fine for non-gated sources (Vimeo, archive.org, …).
#
#   ZDOTS_YTDLP_COOKIES_FILE          path to a Netscape cookies.txt export
#   ZDOTS_YTDLP_COOKIES_FROM_BROWSER  browser to read live cookies from
#                                     (firefox|chrome|safari|brave|edge[:profile])
#
# File wins if both are set. On this PHI-adjacent machine the knobs stay OFF
# unless the operator sets them: browser cookies are passed only to yt-dlp for
# the fetch — never written to the DB, the analytics store, or a log.
#
# Both call sites source this so the metadata fetch and the download use the
# SAME strategy (if they diverged, one would 200 while the other bot-gated).

# Print the yt-dlp cookie args, one per line (nothing if unconfigured). Callers
# read the lines into an array so paths/profiles with spaces survive intact.
zdots_ytdlp_cookie_args() {
  if [[ -n "${ZDOTS_YTDLP_COOKIES_FILE:-}" ]]; then
    printf '%s\n' --cookies "$ZDOTS_YTDLP_COOKIES_FILE"
  elif [[ -n "${ZDOTS_YTDLP_COOKIES_FROM_BROWSER:-}" ]]; then
    printf '%s\n' --cookies-from-browser "$ZDOTS_YTDLP_COOKIES_FROM_BROWSER"
  fi
}

# Read the cookie args into a named-by-convention array `_ytdlp_cookies` in the
# CALLER's scope. bash 3.2 has no namerefs, so this is a sourced snippet helper:
#   _ytdlp_cookies=(); zdots_ytdlp_load_cookies
# Expand with the set -u guard: "${_ytdlp_cookies[@]+"${_ytdlp_cookies[@]}"}"
zdots_ytdlp_load_cookies() {
  _ytdlp_cookies=()
  local _a
  while IFS= read -r _a; do _ytdlp_cookies+=("$_a"); done < <(zdots_ytdlp_cookie_args)
}

# After a failed fetch, print a remediation hint — but ONLY when no cookie
# strategy is configured. A failure WITH cookies set is a different problem
# (expired cookies, geo-block, dead URL) and must not get a misleading hint.
zdots_ytdlp_cookie_hint() {
  [[ -n "${ZDOTS_YTDLP_COOKIES_FILE:-}${ZDOTS_YTDLP_COOKIES_FROM_BROWSER:-}" ]] && return 0
  {
    printf 'yt-dlp fetch failed. If this is a bot-gated site (e.g. YouTube), set a cookie source:\n'
    printf '  export ZDOTS_YTDLP_COOKIES_FROM_BROWSER=firefox   # or chrome/safari/brave/edge\n'
    printf '  export ZDOTS_YTDLP_COOKIES_FILE=/path/to/cookies.txt\n'
    printf 'then retry. (Non-gated sources — Vimeo, archive.org — need no cookies.)\n'
  } >&2
}
