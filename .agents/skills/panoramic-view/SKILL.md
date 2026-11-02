---
name: panoramic-view
description: Inspect, compare, and calibrate durable Panoramic workflow evidence without starting processing workers or mixing control runs into operational measurements.
---

# Panoramic View

Panoramic View is permanent process instrumentation. The synthetic tracer is
its control test, not a separate measurement path. Ordinary eligible runs emit
the same versioned evidence envelope.

## Read workflow evidence

- `mp panoramic runs [limit]` lists run, journey, workflow, contract, and run class.
- `mp panoramic journey <journey-uuid>` walks a journey's executions and ordered checkpoint evidence.
- `mp panoramic compare <baseline-run-uuid> <candidate-run-uuid>` compares aligned checkpoint IDs.
- `mp panoramic calibrate <workflow-id> [--flow <flow-id>] [--class operational|control] [--since ISO8601]` reports sample counts, distributions, and route reasons. Operational is the default cohort.
- `mp panoramic evaluate-slos` stores the configured policy-window evaluation. The default policy file has no objectives and raises no Alerts.
- `/panoramic` and `/panoramic/compare` render the same run and comparison services.

These inspection commands do not enqueue or start work. Do not invoke a worker
status command unless its implementation is confirmed read-only. In this
environment, `zdots-ctx worker status` starts a worker.

## Interpret identifiers and outcomes

- `journey_id` is the stable work-item lifecycle identity.
- `run_id` is one execution; completed work processed again gets another run.
- `correlation_id` follows asynchronous jobs and downstream replies. It is not
  the OTel `trace_id`.
- `flow_id` is an immutable workflow contract version; `workflow_id` groups
  comparable versions.
- A gate's eligible/continued/offramp counts are recorded on its decision
  result, never its entry marker. Holds and deferred work are explicit outcomes.
- Checkpoint execution, queue wait, time since prior marker, and handoff
  latency describe different intervals. Do not add them as if disjoint.
- Context Engine remains authoritative for canonical transcription stage
  state. Cross-system links are explicit Panoramic correlation records; legacy
  source-ID matches are fallback evidence.

## Calibrate before setting targets

Use operational runs to derive operating ranges. Inspect control runs
separately. Keep sample counts and workload/version segments visible, use
percentiles rather than normal-distribution assumptions, and do not set target
numbers from sparse or mixed cohorts. A target and Alert activation require an
explicit, versioned policy and an agreed sample/window rule. External Alert
delivery is not configured; active Alert state is visible in the dashboard.

Never place journey/run/source identifiers, titles, paths, or transcript data
in OTel metric labels or Alert labels.
