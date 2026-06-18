---
name: telemetry-volume
description: Diagnose and tame OpenObserve / telemetry store growth on the Observable Control Plane. Use when the O2 store is large, telemetry is filling the disk, zdots-doctor warns "OpenObserve store exceeds cap", or you suspect a spanmetrics cardinality explosion. Fixes volume at the source, not just retention.
---

# /telemetry-volume — Tame the Telemetry Store

The OpenObserve store is **disposable** local telemetry, not a system of record.
When it grows large the reflex is "cut retention" — but retention is a ceiling,
not a brake. The usual cause is **ingest volume** from a derived metric
(spanmetrics histograms), and the fix is at the **source**.

Precedent: Z-156 — `traces_span_metrics_duration_bucket` reached 10 GB (~60% of
a 17 GB store) at ~2 GB/day while retention was healthy. Source tuning cut it to
~1.7 MB.

**Rules:**
- `reinit` wipes disposable telemetry — relief, not a fix. Confirm with the
  operator before running it; it deletes data they may be looking at.
- Telemetry must stay **meaningful**. Reduce waste (exemplars, flush rate), not
  the RED metrics (rate/errors/duration) you actually query.
- The collector config (`etc/otel-collector.yaml`) is **shared across machines** —
  a connector change lands on home *and* work. Per-machine differences go in
  `.zdots.work` (enforced) / `.zdots.local` via `ZDOTS_O2_RETENTION_DAYS`.

---

## Step 1 — Diagnose: is it volume or retention?

```bash
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/openobserve"
du -sh "$DIR"                              # total
du -sh "$DIR"/stream/files/default/* 2>/dev/null | sort -rh | head   # by signal
du -h "$DIR"/stream/files/default/metrics 2>/dev/null | sort -rh | head -15
```

Read the date subdirs (`.../<metric>/2026/06/<day>`). **If the data is all inside
the retention window, retention is working — the problem is the ingest rate.**
A single `traces_span_metrics_*_bucket` dominating the store is the signature.

---

## Step 2 — Relieve pressure (optional, operator-confirmed)

```bash
openobserve-ctl reinit     # wipe disposable store; streams refill in ~15s
```

Reclaims now, but the store refills at the same rate until Step 3. Do not run
unattended.

---

## Step 3 — Cut volume at the source (the real fix)

Edit the spanmetrics connector in `etc/otel-collector.yaml`, in impact order:

| Lever | Change | Effect | Cost |
|-------|--------|--------|------|
| Exemplars | `exemplars: { enabled: false }` | Stops attaching trace IDs to every histogram point — the dominant multiplier | Lose bucket→trace jump; query traces directly |
| Flush | `metrics_flush_interval: 5s → 60s` | ~12× fewer data points/series | RED metrics at 1-min resolution (fine for a dev box) |
| Buckets | trim explicit `buckets:` list | Fewer series | Coarser quantiles at the extremes |
| Dimensions | drop/normalize high-cardinality `span.name`, custom dims | Biggest cut | Risks losing per-operation visibility — the point of spanmetrics |

Validate and apply (the base recompiles to `.generated.yaml` at boot):

```bash
otel-collector validate      # exit 0 required
zsvc restart otel
```

---

## Step 4 — Tighten retention per-machine

```bash
# Home base default lives in bin/openobserve-ctl (ZDOTS_O2_RETENTION_DAYS).
# Work (hotter, PHI-adjacent) — enforce a shorter ceiling in .zdots.work:
export ZDOTS_O2_RETENTION_DAYS=2
```

---

## Step 5 — Verify (two-signal)

```bash
zsvc health otel && openobserve-ctl health           # services up
zdots-o2-query service --since 1h                     # data still flowing
zdots-o2-query streams | grep -o 'traces_span_metrics_[a-z_]*' | sort -u  # RED metrics intact
du -sh "${XDG_DATA_HOME:-$HOME/.local/share}/openobserve"   # footprint
```

Confirm both: the store shrank/stopped growing AND the metrics you rely on are
still present. A small store with no useful telemetry is a regression, not a fix.

---

## Step 6 — Guard against drift

`zdots-doctor` warns when the store exceeds `ZDOTS_O2_SIZE_WARN_GB` (default 8).
Confirm the guard is reachable and reports:

```bash
zdots-doctor 2>&1 | grep -i "OpenObserve store"
```

If volume creeps back, the connector regressed — return to Step 1. For a fix that
needs operator coordination (connector design, new dimensions), file
`zdots-issue --type request`.

---

## Related

- `docs/openobserve.md` · `docs/otel-collector-guide.md` · `docs/storage-hygiene.md`
- `/zdots-heal` Gate 4 surfaces the store-size warning during a health sweep.
