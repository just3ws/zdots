# Observability

Primary surfaces:

- `zdots-ctl status`
- `zdots-ctl check`
- `zdots-status --once`
- `trace-verify`
- `zdots-log-analyze`

OTel may be down while non-OTel diagnostics still work. `zdots-log-analyze` packages bootstrap/update/upgrade logs without requiring the collector or OpenObserve.
