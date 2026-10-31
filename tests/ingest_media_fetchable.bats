#!/usr/bin/env bats
# tests/ingest_media_fetchable.bats — fetchability contract for ingest sources.
# Cloud distillation was retired; the file now covers only downloader inputs.

setup() {
  load "setup.bash"
  setup_environment
  ROOT="$REPO_ROOT"
}

# Decoupling gate (downloader/processor): require_fetchable! lets any yt-dlp URL
# source through and refuses only 'local' (no re-fetchable URI).
_fetchable() {
  ruby -e '
    require "'"$ROOT"'/lib/zdots"
    require "'"$ROOT"'/lib/zdots/jobs/ingest_media"
    o = Zdots::Jobs::IngestMedia.allocate
    o.instance_variable_set(:@src, Struct.new(:source_type).new(ARGV[0]))
    begin; o.send(:require_fetchable!); puts "ok"; rescue StandardError; puts "raised"; end
  ' "$1" 2>/dev/null
}

@test "fetchable: twitter/youtube/vimeo pass (yt-dlp fetches them)" {
  [ "$(_fetchable twitter)" = "ok" ]
  [ "$(_fetchable youtube)" = "ok" ]
  [ "$(_fetchable vimeo)" = "ok" ]
}

@test "fetchable: local is refused (no re-fetchable URI)" {
  [ "$(_fetchable local)" = "raised" ]
}
