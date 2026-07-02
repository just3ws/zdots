#!/usr/bin/env bats
# tests/ingest_pipeline_diagram.bats — the process-description contract (Z-188).
#
# docs/generated/ingest-pipeline.mmd is a Mermaid projection of the declared
# IngestMedia::PIPELINE. It is generated FROM the code, never hand-edited — this
# test regenerates it and fails on drift, so the diagram can never lie about what
# runs (BPMN as description, code as execution; the executable is the contract).
# Regenerate after changing PIPELINE:
#   zdots-ruby -e 'require "./lib/zdots"; require "./lib/zdots/jobs/ingest_media"; \
#     print Zdots::Jobs::IngestMedia.to_mermaid' > docs/generated/ingest-pipeline.mmd

setup() {
  load "setup.bash"
  setup_environment
  ROOT="$REPO_ROOT"
}

@test "ingest pipeline Mermaid matches the declared PIPELINE (no drift)" {
  local generated committed
  generated="$(ruby -e 'require "'"$ROOT"'/lib/zdots"; require "'"$ROOT"'/lib/zdots/jobs/ingest_media"; print Zdots::Jobs::IngestMedia.to_mermaid')"
  committed="$(cat "$ROOT/docs/generated/ingest-pipeline.mmd")"
  [ "$generated" = "$committed" ]
}

@test "every declared PIPELINE stage has an executor binding (no orphan)" {
  # run_stage raises 'unknown pipeline stage' for a stage it can't execute;
  # assert none of the declared stages hit that path.
  run ruby -e '
    require "'"$ROOT"'/lib/zdots"
    require "'"$ROOT"'/lib/zdots/jobs/ingest_media"
    o = Zdots::Jobs::IngestMedia.allocate
    missing = Zdots::Jobs::IngestMedia::PIPELINE.map { |s| s[:stage] }.reject do |name|
      # a bound stage fails on the missing @src/deps, NOT on "unknown pipeline stage"
      begin; o.send(:run_stage, name); true
      rescue => e; !e.message.include?("unknown pipeline stage")
      end
    end
    puts missing.empty? ? "all-bound" : "orphans:#{missing.join(",")}"
  ' 2>/dev/null
  [ "$output" = "all-bound" ]
}
