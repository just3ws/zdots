# Operational Feedback System — Design Spec

Captures issues, requests, and friction from users/agents. Feeds patterns to recommendation engine. Closes the Virtuous Loop: Work → Capture → **Report Issues** → Curate → Recommend → Repeat.

---

## Overview

The **Operational Feedback System** is an extension of the Virtuous Loop that captures operational friction (bugs, missing features, user confusion) and uses pattern analysis to recommend improvements.

```
Virtuous Loop (existing)           Operational Feedback (new)
Work                               Error occurs / Feature request filed
  ↓                                  ↓
Capture (session residue)         Report Issue (automatic or manual)
  ↓                                  ↓
Curate (lessons)                  Pattern Analysis (detect patterns)
  ↓                                  ↓
Infer (improved AI context)       Recommend (suggest improvements)
  ↓                                  ↓
Loop                              Loop (back to Curate)
```

---

## 1. Issue Reporting

### 1.1 Explicit Reporting: `zdots-issue`

**Existing command, enhanced:**

```bash
# Report an error (with context)
zdots-issue "PHI scrubber fails on large inputs"
# Captures: title, description, trace_id (if available), environment

# Report a feature request
zdots-issue --type request "I need to export lessons to Markdown"

# Report friction (not a bug, but hard to use)
zdots-issue --type friction "It's confusing how to silence an alert"

# Detailed report (with more context)
zdots-issue \
  --type error \
  --severity high \
  --title "zdots-ctx migrate fails with password rotation" \
  --description "When rotating creds, migration hangs for 5+ minutes" \
  --reproduction "1. Run zdots-ctx rotate-creds; 2. Check DB migrations"

# Report from script (no interactive)
zdots-issue --title "Nightly sync failed" --type error --from-trace abc123def456
```

**What gets captured:**

```yaml
# Stored in PostgreSQL: operational_feedback table

id: 12345
reporter: "pi-agent"                    # who reported it (Actor)
type: error | request | friction        # category
severity: low | medium | high | critical # severity (if applicable)
title: "PHI scrubber fails on large inputs"
description: "When processing >10MB payload..."
trace_id: "abc123def456"               # links to execution context (OTEL trace)
environment:
  machine: powerstation
  zdots_version: 2026-06-12
  ai_mode: local
  services_running: [llama, context-engine, otel-collector]
status: open | wontfix | fixed         # resolution status
created_at: 2026-06-12T14:30:00Z
updated_at: 2026-06-12T14:30:00Z
tags: [performance, database, ai]      # user-provided or auto-tagged
links:                                 # related issues
  - duplicates: 12340
  - related: 12342, 12344
attachments:                           # optional logs, stack traces
  - trace_export.json
  - error.log
```

### 1.2 Automatic Reporting

Certain error conditions auto-report (with opt-out):

```bash
# In .zdots/config.yaml
observability:
  auto_report_errors: true            # auto-file issues on crashes
  auto_report_threshold: "high"       # only high-severity errors
  auto_report_include_trace: true     # attach OTEL trace

# In code: any hard error can emit auto-report
if critical_failure; then
  zdots_auto_issue --severity critical --category ai
fi

# Opt-out per-command
ZDOTS_NOAUTOREPORT=1 zdots-ctx migrate

# Opt-out per-error-type
ZDOTS_SUPPRESS_AUTOREPORT="migrate_timeout,db_connection" zdots-ctl check
```

**Auto-report triggers:**

- Unhandled exceptions (Ruby code)
- Command timeout (>5min for long-running ops)
- Service crash (auto-restart + auto-report)
- PHI scrubber initialization failure
- Database connection failure (after retries exhausted)
- Out-of-memory / resource exhaustion
- Security violation (e.g., non-local AI endpoint in local mode)

**Opinionated defaults:**

- Auto-report enabled by default (privacy-conscious machines can disable)
- Reports are **never** sent to cloud; stored locally only
- Reports include trace (for debugging), but redact secrets
- Deduplicate: same error within 5 minutes = one report + counter

---

## 2. Pattern Analysis Engine

Runs periodically (every 6 hours, configurable) to detect patterns:

```bash
# Manual trigger
zdots recommend --analyze

# Scheduled (background job)
# Runs via Worker: claim job type="pattern_analysis"
```

### 2.1 Pattern Types

**Error Clustering:**
```
Detect: Same error appearing N times in period T

Pattern: "PHI Scrubber timeout on >10MB"
Frequency: 4 reports in last 7 days
Severity: high (affects AI pipeline)
Affected: [pi-agent, deploy-bot, aider-agent]
Recommendation: "Optimize PHI scrubber regex; consider streaming"
Action: File bug ticket in backlog
```

**Feature Request Aggregation:**
```
Pattern: "Export lessons to Markdown"
Frequency: 3 requests in last 30 days
Sources: [pi-agent, user-1, user-2]
Recommendation: "Feature has demand; estimate effort"
Action: Add to Feature backlog with priority
```

**Friction Pattern (User Confusion):**
```
Pattern: "How to silence alerts" or "Alert system confusing"
Frequency: 2 friction reports + 3 help requests
Recommendation: "Documentation gap or UX issue; improve help"
Action: Add FAQ entry or improve `zdots help alert`
```

**Cascading Failures:**
```
Pattern: Error X always followed by Error Y within 5min

Pattern: "Credential rotation fails" → "DB migration hangs"
Frequency: 3 cascades in last 14 days
Recommendation: "Root cause: rotation + migration race condition"
Action: Fix underlying issue; prevents cascades
```

**Performance Regression:**
```
Pattern: Command latency increasing over time

Metric: `zdots-ctx sync-history` latency
Trend: 5 reports, increasing: 30s → 45s → 60s → 90s → 120s
Duration: last 30 days
Recommendation: "Performance degradation detected; investigate DB"
Action: Profile and optimize
```

### 2.2 Pattern Analysis Algorithm

```yaml
# Pseudocode for pattern detection

for each issue_type in [errors, requests, friction]:
  for each error_class in group_by_title(issues):
    count = count(issues matching error_class in last 30d)
    if count >= threshold:  # e.g., 3+ occurrences
      affected_agents = unique(issue.reporter)
      severity = max(issue.severity)
      trend = analyze_temporal_pattern(count over time)
      
      if severity == high or count >= 5:
        emit_recommendation(error_class, count, affected_agents, trend)

for each feature_request:
  requests_by_feature = group_by_feature(requests)
  for each feature, count in requests_by_feature:
    if count >= 2:  # 2+ requests = signal
      emit_recommendation("feature_request", feature, count)

for each error_pair(error_x, error_y):
  cascades = count(issue_x followed_by issue_y within 5min)
  if cascades >= 2:
    emit_recommendation("cascade", error_x, error_y, cascades)
```

---

## 3. Recommendation Engine

Outputs actionable recommendations based on patterns:

```bash
# View recommendations
zdots recommend                    # all recommendations
zdots recommend --severity high    # high-impact only
zdots recommend --last 7d          # generated in last 7 days
zdots recommend --category ai      # filter by domain

# Example output:
# CRITICAL (4 occurrences, last 7d, 3 agents affected)
#   "PHI Scrubber timeout on payloads >10MB"
#   Recommendation: Optimize regex compilation; consider streaming
#   Action: File bug Z-XXXX
#
# FEATURE REQUEST (3 occurrences, last 30d)
#   "Export lessons to Markdown"
#   Recommendation: Feature has demand; estimate 2-3 days
#   Action: Add to backlog; discuss with PI
#
# FRICTION (2 friction reports + 3 help requests, last 14d)
#   "Alert system confusing"
#   Recommendation: Improve help text or UX; low-hanging fruit
#   Action: Add FAQ entry to `zdots help alert`

# Act on a recommendation
zdots recommend act Z-XXXX              # file bug ticket
zdots recommend act "feature: export"   # add to backlog
zdots recommend dismiss Z-YYYY          # acknowledge but defer
```

### 3.1 Recommendation Scorecard

Each recommendation gets a score (urgency × impact):

```yaml
score = (frequency × severity × affected_agents_count) / days_since_first
# Example: (4 × high(3) × 3 agents) / 7 days = 5.14 (high priority)

categories:
  critical: score >= 5.0
  high: 2.0 <= score < 5.0
  medium: 0.5 <= score < 2.0
  low: score < 0.5
```

---

## 4. Knowledge System Integration

Issues become Lessons when curated:

```yaml
# Operational issue in PostgreSQL
id: 12345
type: error
title: "PHI Scrubber timeout on >10MB"
description: "When processing large payloads, regex compilation times out"
pattern_analysis: "Detected in 4 reports; all agents affected"
trace_id: [abc123, def456, ghi789, jkl012]  # linked traces

# Curated into Lesson
id: lesson-456
source: "issue #12345"
title: "PHI Scrubber performance: large-payload optimization"
content: |
  The PHI Scrubber regex compiles on first use. For payloads >10MB,
  this causes a 30+ second timeout. Solution: pre-compile regexes at
  startup and cache them. See cmd/zdots-phi-scrub/main.go:47.
tags: [performance, phi-scrubber, regex-optimization]
```

### 4.1 Automatic Lesson Promotion

When a recommendation is acted on (bug fixed, feature implemented, doc improved):

```bash
# Developer fixes the bug
git commit -m "fix: optimize PHI scrubber for large payloads"

# CI detects: "closes Z-XXXX" in commit message
# Looks up recommendation #12345
# Automatically curates issue into Lesson:
#   "PHI Scrubber optimization (completed)"
#   Tags: [performance, ai, completed]
#   Status: resolved

# Future AI can hydrate context:
# "When asked about PHI scrubber performance, I know it was optimized in Jun 2026"
```

---

## 5. Query Interface

Agents and tools can query the feedback system:

```bash
# List open issues
zdots issue list --status open

# Find related issues
zdots issue search "PHI scrubber"
zdots issue search --tag performance --last 30d

# View issue details
zdots issue show 12345

# Add comment to issue
zdots issue comment 12345 "I also see this with large JSON files"

# Link issues (mark as duplicate)
zdots issue link 12345 12346 --relation duplicate

# Resolve issue
zdots issue resolve 12345 --status fixed --closure "Optimized regex in PR #4521"

# Export for analysis
zdots issue export --format csv --last 90d > feedback-export.csv
zdots issue export --format json | jq '.[] | select(.severity=="high")'
```

---

## 6. Integration with Recommendation Loop

Complete flow:

```
1. Agent/User reports issue (explicit or auto-capture)
   ↓
2. Issue stored in PostgreSQL (operational_feedback table)
   ↓
3. Pattern analysis job runs (every 6 hours)
   → Detects patterns (errors, features, cascades, friction)
   → Generates recommendations
   → Stores in recommendations table
   ↓
4. `zdots recommend` shows recommendations to humans/agents
   ↓
5. Operator acts (file bug, add to backlog, dismiss, improve docs)
   ↓
6. Dev fixes issue / implements feature / improves UX
   ↓
7. Commit message references issue ("closes Z-XXXX")
   ↓
8. CI auto-curates issue into Lesson (tagged, timestamped)
   ↓
9. Future AI hydrates context when relevant
   ↓
10. Loop: Knowledge base improves, recommendations reduce (pattern resolved)
```

---

## 7. Privacy & Security

Issues are **never sent to cloud**:
- Stored locally in PostgreSQL
- Can be exported/shared, but under user control
- Traces include redacted PHI (patterns, not values)
- Auto-report has opt-out + toggle per-category

**Trace inclusion:**
- Issues can link to OTEL traces (for debugging)
- Traces are scrubbed (PHI removed) before export
- Sensitive traces can be excluded on export

---

## 8. Implementation Notes

### 8.1 Schema

```sql
-- PostgreSQL

CREATE TABLE operational_feedback (
  id SERIAL PRIMARY KEY,
  report_type VARCHAR(20) NOT NULL,  -- error, request, friction
  severity VARCHAR(20),               -- low, medium, high, critical (optional)
  title VARCHAR(500) NOT NULL,
  description TEXT,
  reporter VARCHAR(255),              -- actor name
  trace_id VARCHAR(255),              -- link to OTEL trace
  environment JSONB,                  -- machine, version, config
  status VARCHAR(50) DEFAULT 'open',  -- open, wontfix, fixed, duplicate
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  tags TEXT[]
);

CREATE TABLE recommendations (
  id SERIAL PRIMARY KEY,
  category VARCHAR(50),               -- error_cluster, feature_request, cascade, friction
  pattern VARCHAR(500),
  frequency INTEGER,                  -- N occurrences
  severity VARCHAR(20),
  affected_actors TEXT[],             -- list of reporters
  recommendation TEXT,
  action VARCHAR(100),                -- file_bug, add_to_backlog, improve_docs, dismiss
  score FLOAT,                        -- urgency × impact
  generated_at TIMESTAMP DEFAULT NOW(),
  acted_on BOOLEAN DEFAULT FALSE,
  related_issue_id INTEGER REFERENCES operational_feedback(id)
);

CREATE INDEX idx_feedback_type_status ON operational_feedback(report_type, status);
CREATE INDEX idx_feedback_created ON operational_feedback(created_at DESC);
CREATE INDEX idx_recommendations_score ON recommendations(score DESC);
```

### 8.2 Commands

```bash
# File an issue
zdots-issue "Title" [--type request|error|friction] [--severity high|medium|low]

# View recommendations
zdots recommend [--category ai|database|ui] [--severity high] [--last 7d]

# Manage issues
zdots issue list|search|show|comment|resolve|link|export
```

### 8.3 Jobs

New Worker job types:
- `pattern_analysis` — runs every 6 hours, detects patterns
- `recommendation_generation` — generates recommendations from patterns
- `lesson_auto_promotion` — when issue is resolved, curate into Lesson

---

## 9. Example: Full Cycle

**Day 1: Agent reports issue**
```bash
$ zdots-issue --type error \
  --severity high \
  --title "PHI Scrubber timeout on large inputs" \
  --description "Processing 50MB file hangs for 5+ minutes"

Issue #12345 filed
```

**Day 2: Second report**
```bash
$ zdots-issue --type error \
  --title "PHI Scrubber hangs on big JSON" \
  --description "Debugging payload >30MB stalls"

Issue #12346 filed (similar to #12345, tagged as related)
```

**Day 3: Pattern analysis runs**
```bash
$ zdots recommend --analyze
# System detects: 2 reports of PHI Scrubber timeout in 3 days
# Score: (2 × high(3) × 2 agents) / 3 = 4.0 (high priority)
# Recommendation: "PHI Scrubber performance issue; optimize regex"
```

**Day 4: Operator reviews**
```bash
$ zdots recommend
# [HIGH] PHI Scrubber timeout on payloads >10MB (2 occurrences, 3 days)
#   Recommendation: Optimize regex; consider streaming
#   Action: File bug Z-XXXX

$ zdots recommend act "PHI Scrubber"
# Bug Z-XXXX created and linked
```

**Day 10: Dev fixes issue**
```bash
$ git commit -m "fix: optimize PHI scrubber regex compilation

Precompile regexes at startup instead of lazy-compile on first use.
Reduces latency for large payloads from 5min → 200ms.

Fixes Z-XXXX"

# CI detects: "Fixes Z-XXXX"
# Looks up issue #12345
# Auto-curates into Lesson: "PHI Scrubber optimization (completed)"
# Tags: [performance, completed, ai, 2026-06-20]
```

**Day 11: Future agent hydrates context**
```bash
$ pi-agent: "Optimize my PHI scrubbing code"
# Hydrate: lessons tagged [performance, ai, recently-completed]
# Returns: "PHI Scrubber was optimized in Jun 2026; see commit abc123"
```

---

## 10. Success Metrics

- **Reduction in duplicate reports:** Same issue < 2 occurrences/month
- **Response time:** Issues → fixes in < 30 days on high-priority items
- **Lessons generated:** 1 Lesson per 5 issues resolved (20% curation rate)
- **Agent satisfaction:** Agents see their feedback acted on; trust increases
- **Pattern detection accuracy:** Detect 80%+ of actual bugs/friction early

---

## 11. Open Questions

1. Should issues be tagged automatically (ML-based tagging)?
2. Should recommendations auto-age (old recommendations archived)?
3. Should there be a public/shared issue tracker, or always private?
4. How do we handle security issues (reported privately)?
5. Should cascading failures auto-link issues without user intervention?
