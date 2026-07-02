---
id: Z-187
title: >-
  [agent-issue] mise Python lacks CA trust — yt-dlp/zdots-ingest-media fail SSL
  without manual SSL_CERT_FILE
status: To Do
assignee: []
created_date: '2026-07-01 13:46'
updated_date: '2026-07-01 16:35'
labels:
  - agent-reported
  - error
dependencies: []
priority: medium
ordinal: 83890
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Type:** error
**Severity:** medium
**Trace ID:** `5b4468133af32eac3c5e4c0e472302a1`

Trying to ingest a public X-hosted video via 'zdots-ingest-media <url>', yt-dlp failed with: [SSL: CERTIFICATE_VERIFY_FAILED] unable to get local issuer certificate. Root cause: the mise-managed Python (3.14.5, ~/.local/share/mise/installs/python/3.14.5) has no CA bundle wired into its SSL default, so any yt-dlp (and anything using requests/urllib) fails cert verification against normal HTTPS hosts. X access itself is fine — yt-dlp reached the guest-token/GraphQL/m3u8 stages once trust was supplied.

Workaround that works: export SSL_CERT_FILE (and REQUESTS_CA_BUNDLE) to the certifi bundle at .../python/3.14.5/lib/python3.14/site-packages/certifi/cacert.pem before invoking.

Impact: (1) foreground zdots-ingest-media needs the manual env; (2) MORE important — the zdots-worker launchd daemon that processes transcription/distill jobs carries only HOME/PATH/ZDOTDIR in its plist, so if it re-downloads via yt-dlp it will hit the same SSL failure with no way to set the env per-invocation. Suggest: wire SSL_CERT_FILE=certifi (or configure the mise Python's openssl trust) at the environment level and in the worker plist env keys, so ingest-media works out of the box.

Not fixing myself — filing per the environment-gap policy.

---
*Filed via `zdots-issue`. Operator review required before any changes are made.*
*Do not modify zdots to work around this issue — wait for operator resolution.*
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CORRECTION (verified 2026-07-01): the zdots-worker is NOT affected — it downloads YouTube/Vimeo fine (85 successful ingests in its log), so no SSL_CERT_FILE is needed in the worker plist. The CA-trust gap only bites INTERACTIVE/foreground yt-dlp (a plain shell invocation). Scope Z-187 to the interactive environment, not the worker. Separately: the real blocker for the X/twitter ingest was NOT SSL but a missing raw-stage handler for source_type=twitter/local in lib/zdots/jobs/ingest_media.rb (the download/processor coupling) — tracked separately.
<!-- SECTION:NOTES:END -->
