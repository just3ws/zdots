# GitHub KB Analysis Validation

Validated on 2026-06-09 with:

```bash
GH_TOKEN=$(gh auth token) ZDOTS_GH_REPO_LIMIT=5 zdots-gh run bats-core --html
```

Observed result:

- harvested 5 `bats-core` repos;
- rendered Markdown, HTML, forensic insights, and graph JSON;
- ingested `gh-delivery-health-bats-core` and `gh-forensics-bats-core`;
- both KB rows had encrypted content and non-null embeddings;
- all `embed` jobs were `completed`;
- text queries found delivery health and forensics reports;
- semantic query `issue coordination cross repo bats-core` returned both reports.

Validation findings filed:

- `Z-140`: `zsvc status embed` reports unhealthy while semantic embedding works.
- `Z-141`: `zdots-gh` auth precheck needs `GH_TOKEN=$(gh auth token)` in this shell.

## Observability Logs & URLs

- Harvested Repository Scope: `bats-core/bats-core`, `bats-core/bats-support`, `bats-core/bats-assert`, `bats-core/bats-file`, `bats-core/bats-detik`
- Observability Trace ID: [placeholder_for_trace_id_if_available]
- Intelligence Ingestion: `gh-delivery-health-bats-core`, `gh-forensics-bats-core`
