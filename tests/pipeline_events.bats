#!/usr/bin/env bats
# Z-247 contract test: every event PipelineEvents emits validates against the
# shipped Draft 7 schema, and the schema rejects contract drift (extra fields).

ROOT="$BATS_TEST_DIRNAME/.."
SCHEMA="$ROOT/etc/pipeline-events.schema.json"

setup() {
  TMP_DIR="$(mktemp -d)"
  export ZDOTS_PIPELINE_EVENTS_FILE="$TMP_DIR/events.jsonl"
}

teardown() {
  rm -rf "$TMP_DIR"
}

_emit_sample_events() {
  ruby -I "$ROOT/lib" -r zdots/pipeline_events -e '
    FakeJob = Struct.new(:id, :type, :attempts, :payload)
    job = FakeJob.new("11111111-2222-3333-4444-555555555555", "ingest_media", 1,
                      { "media_source_id" => "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" })
    Zdots::PipelineEvents.emit(:started, job)
    Zdots::PipelineEvents.emit(:succeeded, job)
    Zdots::PipelineEvents.emit(:failed, job, error: RuntimeError.new("boom with content"))
  '
}

@test "pipeline events: every emitted line validates against the schema" {
  run _emit_sample_events
  [ "$status" -eq 0 ]
  [ -f "$ZDOTS_PIPELINE_EVENTS_FILE" ]

  run python3 -c "
import json, os, jsonschema
schema = json.load(open('$SCHEMA'))
lines = [l for l in open(os.environ['ZDOTS_PIPELINE_EVENTS_FILE']) if l.strip()]
assert len(lines) == 3, f'expected 3 events, got {len(lines)}'
for line in lines:
    jsonschema.validate(json.loads(line), schema)
print('ok')
"
  [ "$status" -eq 0 ]
}

@test "pipeline events: failed event carries error_class, never the message" {
  run _emit_sample_events
  [ "$status" -eq 0 ]

  run grep -c '"error_class":"RuntimeError"' "$ZDOTS_PIPELINE_EVENTS_FILE"
  [ "$output" = "1" ]
  # The exception MESSAGE must never appear — messages can carry content.
  run grep -c 'boom with content' "$ZDOTS_PIPELINE_EVENTS_FILE"
  [ "$output" = "0" ]
}

@test "pipeline events: schema rejects unknown fields (contract drift)" {
  run python3 -c "
import json, jsonschema
schema = json.load(open('$SCHEMA'))
event = {'ts': '2026-07-21T00:00:00.000Z',
         'job_id': '11111111-2222-3333-4444-555555555555',
         'job_type': 'embed', 'event': 'started',
         'sneaky_content': 'patient data'}
try:
    jsonschema.validate(event, schema)
    raise SystemExit('validated but should have been rejected')
except jsonschema.ValidationError:
    print('rejected as expected')
"
  [ "$status" -eq 0 ]
}

@test "pipeline events: emit failure degrades to a warning, never raises" {
  export ZDOTS_PIPELINE_EVENTS_FILE="/dev/null/impossible/events.jsonl"
  run ruby -I "$ROOT/lib" -r zdots/pipeline_events -e '
    FakeJob = Struct.new(:id, :type, :attempts, :payload)
    Zdots::PipelineEvents.emit(:started, FakeJob.new("x", "embed", 1, nil))
    puts "survived"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"survived"* ]]
}
