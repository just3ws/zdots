-- etc/zdots-gh/warehouse.sql — DuckDB warehouse for zdots-gh.
--
-- Built by `zdots-gh warehouse <owner>`. The bin substitutes __DATA_DIR__ with
-- the owner's JSON cache directory, then pipes this file to `duckdb <owner>.duckdb`.
--
-- Input shape: `gh api graphql --paginate --slurp` writes a JSON array of
-- response pages per repo. read_json_auto reads each page object as a row whose
-- `data.repository.{pullRequests,issues}.nodes[]` hold the records. union_by_name
-- tolerates repos that returned different optional fields (or zero PRs/issues).
--
-- Every view referenced by report.py is defined here — no dangling references
-- (the PoC's setup_db.sql and generate_report.py had drifted out of sync).

INSTALL json; LOAD json;

-- ── Raw ingestion (resilient to missing/empty files) ─────────────────────────
CREATE OR REPLACE TABLE raw_pr_pages AS
  SELECT * FROM read_json_auto('__DATA_DIR__/*_prs.json',    union_by_name=true, maximum_object_size=67108864);
CREATE OR REPLACE TABLE raw_issue_pages AS
  SELECT * FROM read_json_auto('__DATA_DIR__/*_issues.json', union_by_name=true, maximum_object_size=67108864);

-- ── Explode connection nodes ─────────────────────────────────────────────────
CREATE OR REPLACE TABLE pr_nodes AS
  SELECT data.repository.nameWithOwner AS repo_name,
         unnest(data.repository.pullRequests.nodes) AS node
  FROM raw_pr_pages
  WHERE data.repository.pullRequests.nodes IS NOT NULL;

CREATE OR REPLACE TABLE issue_nodes AS
  SELECT data.repository.nameWithOwner AS repo_name,
         unnest(data.repository.issues.nodes) AS node
  FROM raw_issue_pages
  WHERE data.repository.issues.nodes IS NOT NULL;

-- ── Flattened core tables ────────────────────────────────────────────────────
CREATE OR REPLACE TABLE prs AS
  SELECT repo_name,
         node.number                          AS number,
         node.title                           AS title,
         node.state                           AS state,
         node.author.login                    AS author,
         node.createdAt::TIMESTAMP            AS created_at,
         node.mergedAt::TIMESTAMP            AS merged_at,
         coalesce(node.reviewThreads.totalCount, 0) AS thread_count,
         node.statusCheckRollup.state         AS ci_state,
         node.headRefName                     AS head_ref,    -- Phase 2
         node.baseRefName                     AS base_ref,    -- Phase 2
         coalesce(node.isDraft, false)        AS is_draft,    -- Phase 2
         node.mergedBy.login                  AS merged_by,   -- Phase 2 (who_merges)
         coalesce(node.reviewRequests.totalCount, 0) AS review_requests, -- Phase 2
         (node.author.login IS NULL
            OR node.author.login LIKE 'app/%'
            OR lower(node.author.login) LIKE '%[bot]%'
            OR lower(node.author.login) LIKE '%bot')   AS is_bot
  FROM pr_nodes;

CREATE OR REPLACE TABLE pr_files AS
  SELECT repo_name,
         node.number AS pr_number,
         f.path      AS file_path,
         coalesce(f.additions, 0) AS additions,
         coalesce(f.deletions, 0) AS deletions
  FROM pr_nodes, unnest(node.files.nodes) AS t(f)
  WHERE node.files.nodes IS NOT NULL;

CREATE OR REPLACE TABLE pr_reviews AS
  SELECT repo_name,
         node.number AS pr_number,
         r.author.login AS reviewer,
         r.state        AS review_state,
         r.createdAt::TIMESTAMP AS reviewed_at
  FROM pr_nodes, unnest(node.reviews.nodes) AS t(r)
  WHERE node.reviews.nodes IS NOT NULL AND r.author.login IS NOT NULL;

CREATE OR REPLACE TABLE pr_comments AS
  SELECT repo_name,
         node.number AS pr_number,
         c.author.login AS commenter,
         c.createdAt::TIMESTAMP AS commented_at
  FROM pr_nodes, unnest(node.comments.nodes) AS t(c)
  WHERE node.comments.nodes IS NOT NULL AND c.author.login IS NOT NULL;

-- PR → closing issue links (drives spec-to-code lifecycle).
CREATE OR REPLACE TABLE pr_issue_links AS
  SELECT repo_name,
         coalesce(json_extract_string(to_json(ci), '$.repository.nameWithOwner'), repo_name) AS issue_repo_name,
         node.number AS pr_number,
         ci.number   AS issue_number,
         node.createdAt::TIMESTAMP AS pr_created_at,
         node.mergedAt::TIMESTAMP  AS pr_merged_at
  FROM pr_nodes, unnest(node.closingIssuesReferences.nodes) AS t(ci)
  WHERE node.closingIssuesReferences.nodes IS NOT NULL;

CREATE OR REPLACE TABLE issues AS
  SELECT repo_name,
         node.number               AS number,
         node.title                AS title,
         node.state                AS state,
         node.author.login         AS author,
         node.createdAt::TIMESTAMP AS created_at,
         node.closedAt::TIMESTAMP  AS closed_at,
         node.milestone.title      AS milestone,                  -- Phase 2
         coalesce(node.reopened.totalCount, 0) AS reopen_count    -- Phase 2 (rework)
  FROM issue_nodes;

-- Issue discussion + ownership (Phase 2). src: issue GraphQL  [observed]
CREATE OR REPLACE TABLE issue_comments AS
  SELECT repo_name, node.number AS issue_number,
         c.author.login         AS commenter,
         c.createdAt::TIMESTAMP  AS commented_at
  FROM issue_nodes, unnest(node.comments.nodes) AS t(c)
  WHERE node.comments.nodes IS NOT NULL AND c.author.login IS NOT NULL;

CREATE OR REPLACE TABLE issue_assignees AS
  SELECT repo_name, node.number AS issue_number, a.login AS assignee
  FROM issue_nodes, unnest(node.assignees.nodes) AS t(a)
  WHERE node.assignees.nodes IS NOT NULL;

-- ── Phase-2 REST sources (field-projected arrays; explicit columns so empty
--    estates yield typed-empty tables, never a no-schema bind error) ──────────
CREATE OR REPLACE TABLE repo_meta AS
  SELECT * FROM read_json('__DATA_DIR__/*_meta.json', format='array',
    columns={repo_name:'VARCHAR', default_branch:'VARCHAR', language:'VARCHAR',
             archived:'BOOLEAN', private:'BOOLEAN', fork:'BOOLEAN',
             created_at:'TIMESTAMP', pushed_at:'TIMESTAMP',
             stargazers_count:'BIGINT', forks_count:'BIGINT', open_issues_count:'BIGINT'},
    maximum_object_size=67108864);

CREATE OR REPLACE TABLE workflows AS
  SELECT * FROM read_json('__DATA_DIR__/*_workflows.json', format='array',
    columns={repo_name:'VARCHAR', id:'BIGINT', name:'VARCHAR', path:'VARCHAR', state:'VARCHAR'},
    maximum_object_size=67108864);

CREATE OR REPLACE TABLE workflow_runs AS
  SELECT * FROM read_json('__DATA_DIR__/*_runs.json', format='array',
    columns={repo_name:'VARCHAR', id:'BIGINT', name:'VARCHAR', workflow_id:'BIGINT',
             conclusion:'VARCHAR', status:'VARCHAR', event:'VARCHAR', head_branch:'VARCHAR',
             actor:'VARCHAR', triggering_actor:'VARCHAR',
             created_at:'TIMESTAMP', run_started_at:'TIMESTAMP', updated_at:'TIMESTAMP'},
    maximum_object_size=67108864);

CREATE OR REPLACE TABLE releases AS
  SELECT * FROM read_json('__DATA_DIR__/*_releases.json', format='array',
    columns={repo_name:'VARCHAR', id:'BIGINT', tag_name:'VARCHAR', name:'VARCHAR',
             draft:'BOOLEAN', prerelease:'BOOLEAN', author:'VARCHAR',
             created_at:'TIMESTAMP', published_at:'TIMESTAMP'},
    maximum_object_size=67108864);

-- ── DevEx / DORA views ───────────────────────────────────────────────────────

-- Pipeline instability ("tinkering rate"): share of PRs touching CI workflows.
CREATE OR REPLACE VIEW pipeline_instability AS
  SELECT repo_name,
         count(DISTINCT pr_number) AS workflow_modifying_prs,
         sum(additions + deletions) AS workflow_churn,
         round(count(DISTINCT pr_number)::DOUBLE
               / nullif((SELECT count(*) FROM prs p2 WHERE p2.repo_name = f.repo_name), 0) * 100, 1)
           AS tinkering_rate_percent
  FROM pr_files f
  WHERE file_path LIKE '.github/workflows/%'
  GROUP BY repo_name
  ORDER BY workflow_churn DESC;

-- Test resonance: test churn vs logic churn per PR. >1.0 = healthy investment.
CREATE OR REPLACE VIEW test_files AS
  SELECT *,
         (file_path LIKE '%_test.go' OR file_path LIKE 'spec/%' OR file_path LIKE 'test/%'
          OR file_path LIKE 'tests/%' OR file_path LIKE '%_spec.rb' OR file_path LIKE '%_test.rb'
          OR file_path LIKE '%.test.ts' OR file_path LIKE '%.test.js' OR file_path LIKE '%.spec.ts'
          OR file_path LIKE '%_test.py' OR file_path LIKE 'test_%.py') AS is_test
  FROM pr_files;

CREATE OR REPLACE VIEW test_resonance AS
  WITH pr_stats AS (
    SELECT repo_name, pr_number,
           sum(CASE WHEN is_test THEN additions + deletions ELSE 0 END) AS test_churn,
           sum(CASE WHEN NOT is_test AND file_path NOT LIKE '%lock%'
                    THEN additions + deletions ELSE 0 END) AS code_churn
    FROM test_files GROUP BY repo_name, pr_number)
  SELECT p.repo_name, p.number, p.author,
         CASE WHEN s.code_churn = 0 THEN 1.0
              ELSE s.test_churn::DOUBLE / s.code_churn END AS resonance_ratio
  FROM prs p JOIN pr_stats s
    ON p.repo_name = s.repo_name AND p.number = s.pr_number
  WHERE NOT p.is_bot;

-- Developer mobility / bus factor: who spans the most repos (the "glue").
CREATE OR REPLACE VIEW developer_mobility AS
  SELECT author,
         count(DISTINCT repo_name) AS repo_count,
         count(*)                  AS total_prs
  FROM prs WHERE NOT is_bot AND author IS NOT NULL
  GROUP BY author ORDER BY repo_count DESC, total_prs DESC;

-- Issue lifecycle: spec-to-code (issue→first linked PR) and code-to-merge.
CREATE OR REPLACE VIEW issue_lifecycle AS
  WITH first_pr AS (
    SELECT l.repo_name, l.issue_repo_name, l.issue_number,
           min(l.pr_created_at) AS first_pr_created_at,
           min(l.pr_merged_at)  AS first_pr_merged_at
    FROM pr_issue_links l
    GROUP BY l.repo_name, l.issue_repo_name, l.issue_number)
  SELECT i.repo_name, i.number AS issue_number, i.title, i.author,
         date_diff('hour', i.created_at, fp.first_pr_created_at) AS spec_to_code_hours,
         date_diff('hour', fp.first_pr_created_at, fp.first_pr_merged_at) AS code_to_merge_hours,
         date_diff('hour', i.created_at, fp.first_pr_merged_at) AS total_lead_time_hours
  FROM issues i JOIN first_pr fp
    ON i.repo_name = coalesce(fp.issue_repo_name, fp.repo_name) AND i.number = fp.issue_number
  WHERE fp.first_pr_merged_at IS NOT NULL;

-- Backlog decay: open issues with no linked PR, ranked by how long they linger.
CREATE OR REPLACE VIEW issue_linger AS
  SELECT i.repo_name, i.number, i.title, i.author,
         date_diff('day', i.created_at, now()) AS days_open
  FROM issues i
  LEFT JOIN pr_issue_links l
    ON i.repo_name = coalesce(l.issue_repo_name, l.repo_name) AND i.number = l.issue_number
  WHERE i.state = 'OPEN' AND l.issue_number IS NULL
  ORDER BY days_open DESC;

-- Process leakage (change-failure proxy): merged PRs with CI failure or no review.
CREATE OR REPLACE VIEW process_leakage AS
  SELECT p.repo_name, p.number, p.author, p.ci_state,
         coalesce(rc.review_count, 0) AS review_count
  FROM prs p
  LEFT JOIN (SELECT repo_name, pr_number, count(*) AS review_count
             FROM pr_reviews GROUP BY repo_name, pr_number) rc
    ON p.repo_name = rc.repo_name AND p.number = rc.pr_number
  WHERE p.state = 'MERGED' AND NOT p.is_bot
    AND (p.ci_state = 'FAILURE' OR coalesce(rc.review_count, 0) = 0);

-- Shadow stakeholders: people who review/comment heavily but author ~no PRs.
CREATE OR REPLACE VIEW shadow_stakeholders AS
  WITH social AS (
    SELECT reviewer  AS actor, count(*) AS touches FROM pr_reviews  GROUP BY reviewer
    UNION ALL
    SELECT commenter AS actor, count(*) AS touches FROM pr_comments GROUP BY commenter),
  social_rollup AS (
    SELECT actor, sum(touches) AS social_touches FROM social GROUP BY actor),
  authored AS (
    SELECT author AS actor, count(*) AS prs FROM prs WHERE NOT is_bot GROUP BY author)
  SELECT s.actor,
         s.social_touches,
         coalesce(a.prs, 0) AS authored_prs
  FROM social_rollup s LEFT JOIN authored a ON s.actor = a.actor
  WHERE s.actor IS NOT NULL
    AND lower(s.actor) NOT LIKE '%bot' AND s.actor NOT LIKE 'app/%'
    AND coalesce(a.prs, 0) = 0 AND s.social_touches > 0
  ORDER BY s.social_touches DESC;

-- First-review latency (DevEx feedback-loop friction), hours from open→1st review.
CREATE OR REPLACE VIEW first_review_latency AS
  SELECT p.repo_name, p.number, p.author,
         date_diff('hour', p.created_at, min(r.reviewed_at)) AS hours_to_first_review
  FROM prs p JOIN pr_reviews r
    ON p.repo_name = r.repo_name AND p.number = r.pr_number
  WHERE NOT p.is_bot
  GROUP BY p.repo_name, p.number, p.author, p.created_at;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 1 — Forensic process-inference layer (insights.rb renders these).  ║
-- ║                                                                            ║
-- ║  Design contract:                                                          ║
-- ║   • Every view here is a PURE function of the harvested cache — no now().  ║
-- ║     Anything that needs a report-time reference (open-item age, staleness, ║
-- ║     temporal year buckets) is computed by the renderer with an explicit    ║
-- ║     --as-of literal, so output is reproducible given (cache, as-of).       ║
-- ║   • Confidence class is stated per view: observed / inferred / proxy.      ║
-- ║     "unavailable" insights have NO view — they live in insights-catalog    ║
-- ║     .yaml and surface in the Unknowns & Data Gaps report.                  ║
-- ║   • Source tables are named in each header for traceability.               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Label edges (the existing schema flattened reviews/comments/files but not
-- labels; change-classification and triage inference need them).  [observed]
CREATE OR REPLACE TABLE pr_labels AS
  SELECT repo_name, node.number AS pr_number, lbl.name AS label
  FROM pr_nodes, unnest(node.labels.nodes) AS t(lbl)
  WHERE node.labels.nodes IS NOT NULL;

CREATE OR REPLACE TABLE issue_labels AS
  SELECT repo_name, node.number AS issue_number, lbl.name AS label
  FROM issue_nodes, unnest(node.labels.nodes) AS t(lbl)
  WHERE node.labels.nodes IS NOT NULL;

-- Calendar-correct year bucket relative to a reference timestamp. Day-aware
-- (to_years intervals, not /365) so leap years don't misbucket boundaries.
-- 0 = within last year … 3 = the "3 years ago" window, 4 = older (out of scope).
-- NB: the second param is `ref`, NOT `asof` — ASOF is a DuckDB reserved word.
CREATE OR REPLACE MACRO yr_offset(ts, ref) AS
  CASE WHEN ts >  ref - to_years(1) THEN 0
       WHEN ts >  ref - to_years(2) THEN 1
       WHEN ts >  ref - to_years(3) THEN 2
       WHEN ts >  ref - to_years(4) THEN 3
       ELSE 4 END;

-- ── Flow metrics (cat 3) ─────────────────────────────────────────────────────

-- Per-PR flow record. cycle_hours/churn/handoffs are data-only; open-item age is
-- the renderer's job (needs --as-of).  src: prs, pr_files, pr_reviews, pr_comments  [observed]
CREATE OR REPLACE VIEW pr_flow AS
  SELECT p.repo_name, p.number, p.author, p.state, p.is_bot,
         p.created_at, p.merged_at, p.ci_state,
         CASE WHEN p.merged_at IS NOT NULL
              THEN date_diff('hour', p.created_at, p.merged_at) END AS cycle_hours,
         coalesce(fc.files_changed, 0) AS files_changed,
         coalesce(fc.churn, 0)         AS churn,           -- batch size proxy
         coalesce(rv.reviewers, 0)     AS reviewers,
         coalesce(cm.commenters, 0)    AS commenters,
         coalesce(rv.reviewers, 0) + coalesce(cm.commenters, 0) AS handoffs
  FROM prs p
  LEFT JOIN (SELECT repo_name, pr_number, count(*) files_changed,
                    sum(additions + deletions) churn
             FROM pr_files GROUP BY 1, 2) fc
    ON p.repo_name = fc.repo_name AND p.number = fc.pr_number
  LEFT JOIN (SELECT repo_name, pr_number, count(DISTINCT reviewer) reviewers
             FROM pr_reviews GROUP BY 1, 2) rv
    ON p.repo_name = rv.repo_name AND p.number = rv.pr_number
  LEFT JOIN (SELECT repo_name, pr_number, count(DISTINCT commenter) commenters
             FROM pr_comments GROUP BY 1, 2) cm
    ON p.repo_name = cm.repo_name AND p.number = cm.pr_number;

-- Per-issue flow. resolution_hours data-only; lingering age is renderer-side.
-- src: issues, pr_issue_links  [observed]
CREATE OR REPLACE VIEW issue_flow AS
  SELECT i.repo_name, i.number, i.author, i.state, i.created_at, i.closed_at,
         CASE WHEN i.closed_at IS NOT NULL
              THEN date_diff('hour', i.created_at, i.closed_at) END AS resolution_hours,
         (l.issue_number IS NOT NULL) AS has_linked_pr
  FROM issues i
  LEFT JOIN (SELECT DISTINCT repo_name, issue_repo_name, issue_number FROM pr_issue_links) l
    ON i.repo_name = coalesce(l.issue_repo_name, l.repo_name) AND i.number = l.issue_number;

-- Work-in-progress (open state is a snapshot fact — no time dependence). [observed]
CREATE OR REPLACE VIEW wip_by_repo AS
  SELECT p.repo_name,
         count(*) FILTER (WHERE p.state = 'OPEN' AND NOT p.is_bot) AS open_prs,
         coalesce(oi.open_issues, 0)                              AS open_issues
  FROM prs p
  LEFT JOIN (SELECT repo_name, count(*) FILTER (WHERE state = 'OPEN') open_issues
             FROM issues GROUP BY 1) oi ON p.repo_name = oi.repo_name
  GROUP BY p.repo_name, oi.open_issues;

CREATE OR REPLACE VIEW wip_by_actor AS
  SELECT author AS actor, count(*) AS open_prs
  FROM prs WHERE state = 'OPEN' AND NOT is_bot AND author IS NOT NULL
  GROUP BY author ORDER BY open_prs DESC;

-- Abandoned work: closed without merge.  src: prs  [observed]
CREATE OR REPLACE VIEW abandoned_prs AS
  SELECT repo_name, number, author, created_at
  FROM prs WHERE state = 'CLOSED' AND merged_at IS NULL AND NOT is_bot;

-- ── DORA-adjacent (cat 2) ────────────────────────────────────────────────────

-- PR cycle time (open→merge). src: prs  [observed]
CREATE OR REPLACE VIEW pr_cycle_time AS
  SELECT repo_name, number, author,
         date_diff('hour', created_at, merged_at) AS cycle_hours
  FROM prs WHERE merged_at IS NOT NULL AND NOT is_bot;

-- CI failure rate from statusCheckRollup. PROXY: rollup ≠ a real Actions run;
-- absent rollup means "no signal", not "passed". src: prs  [proxy]
CREATE OR REPLACE VIEW ci_failure_rate AS
  SELECT repo_name,
         count(*) FILTER (WHERE ci_state IS NOT NULL)   AS ci_signals,
         count(*) FILTER (WHERE ci_state = 'FAILURE')   AS failures,
         round(count(*) FILTER (WHERE ci_state = 'FAILURE')::DOUBLE
               / nullif(count(*) FILTER (WHERE ci_state IS NOT NULL), 0), 3) AS failure_rate
  FROM prs WHERE NOT is_bot GROUP BY repo_name;

-- ── Change classification (cat 4) ────────────────────────────────────────────

-- One class per PR from labels + title + file paths, FIRST match wins. The
-- `evidence` column carries the raw inputs (labels, title, file mix) so the
-- decision is always explainable/auditable. Branch names are unavailable in P1.
-- src: prs, pr_labels, pr_files  [inferred]
CREATE OR REPLACE VIEW change_class AS
  WITH lab AS (
    -- ORDER BY keeps the evidence string deterministic for multi-label PRs.
    SELECT repo_name, pr_number,
           string_agg(lower(label), ',' ORDER BY lower(label)) AS labels
    FROM pr_labels GROUP BY 1, 2),
  paths AS (
    SELECT repo_name, pr_number,
           count(*) AS nfiles,
           sum(CASE WHEN file_path LIKE '%_test.go' OR file_path LIKE 'spec/%'
                      OR file_path LIKE 'test/%' OR file_path LIKE 'tests/%'
                      OR file_path LIKE '%_spec.rb' OR file_path LIKE '%_test.rb'
                      OR file_path LIKE '%.test.ts' OR file_path LIKE '%.test.js'
                      OR file_path LIKE '%.spec.ts' OR file_path LIKE '%_test.py'
                      OR file_path LIKE 'test_%.py' THEN 1 ELSE 0 END) AS ntest,
           sum(CASE WHEN file_path LIKE '%.md' OR file_path LIKE 'docs/%'
                      OR file_path LIKE '%/docs/%' THEN 1 ELSE 0 END) AS ndoc,
           sum(CASE WHEN file_path LIKE '.github/workflows/%' THEN 1 ELSE 0 END) AS nci,
           sum(CASE WHEN file_path LIKE '%lock%' OR file_path LIKE '%Gemfile%'
                      OR file_path LIKE '%package.json' OR file_path LIKE '%go.mod'
                      OR file_path LIKE '%go.sum' OR file_path LIKE '%requirements%.txt'
                      THEN 1 ELSE 0 END) AS ndep
    FROM pr_files GROUP BY 1, 2)
  SELECT p.repo_name, p.number, p.author, p.title,
         CASE
           WHEN regexp_matches(coalesce(l.labels, ''), 'security|vuln|cve')
                OR regexp_matches(lower(p.title), '^security|secrets? hygiene|\bcve\b') THEN 'security'
           WHEN regexp_matches(coalesce(l.labels, ''), 'hotfix')
                OR regexp_matches(lower(p.title), 'hotfix')                            THEN 'hotfix'
           WHEN regexp_matches(coalesce(l.labels, ''), 'incident|postmortem|regression') THEN 'incident follow-up'
           WHEN regexp_matches(coalesce(l.labels, ''), 'bug|defect')
                OR regexp_matches(lower(p.title), '^fix|^bug|\bfix(es|ed)?\b')         THEN 'bug fix'
           WHEN regexp_matches(coalesce(l.labels, ''), 'dependenc|dependabot|bump')
                OR regexp_matches(lower(p.title), '^bump|^chore\(deps')
                OR (pp.ndep > 0 AND pp.ndep = pp.nfiles)                               THEN 'dependency update'
           WHEN regexp_matches(coalesce(l.labels, ''), 'support|customer|question')   THEN 'support/customer issue'
           WHEN regexp_matches(coalesce(l.labels, ''), 'feature|enhancement|feat')
                OR regexp_matches(lower(p.title), '^feat|^add |^implement')            THEN 'feature'
           WHEN pp.nfiles > 0 AND pp.ntest = pp.nfiles                                 THEN 'test-only'
           WHEN (pp.nfiles > 0 AND pp.ndoc = pp.nfiles)
                OR regexp_matches(lower(p.title), '^docs')                             THEN 'documentation'
           WHEN (pp.nfiles > 0 AND pp.nci = pp.nfiles)
                OR regexp_matches(coalesce(l.labels, ''), 'infra|^ci$|build|ops')      THEN 'infrastructure'
           WHEN regexp_matches(coalesce(l.labels, ''), 'refactor')
                OR regexp_matches(lower(p.title), '^refactor|^chore|^style')           THEN 'refactor'
           WHEN regexp_matches(coalesce(l.labels, ''), 'release')
                OR regexp_matches(lower(p.title), 'release|^v?\d+\.\d+')               THEN 'release'
           ELSE 'unknown'
         END AS change_class,
         'labels=[' || coalesce(l.labels, '∅') || '] title=[' || lower(p.title)
           || '] files(test/doc/ci/dep/total)='
           || coalesce(pp.ntest, 0) || '/' || coalesce(pp.ndoc, 0) || '/'
           || coalesce(pp.nci, 0)   || '/' || coalesce(pp.ndep, 0) || '/'
           || coalesce(pp.nfiles, 0) AS evidence
  FROM prs p
  LEFT JOIN lab   l  ON p.repo_name = l.repo_name  AND p.number = l.pr_number
  LEFT JOIN paths pp ON p.repo_name = pp.repo_name AND p.number = pp.pr_number
  WHERE NOT p.is_bot;

-- ── Change-management archetypes (cat 8) ─────────────────────────────────────

-- Observed process shape per change, with evidence. Several are proxies (flagged
-- in the catalog): "silent direct-to-main" = merged, zero reviews, merged <24h.
-- src: prs, pr_reviews, pr_issue_links  [inferred/proxy]
CREATE OR REPLACE VIEW change_archetype AS
  WITH rv AS (SELECT repo_name, pr_number, count(*) reviews FROM pr_reviews GROUP BY 1, 2),
       lnk AS (SELECT DISTINCT repo_name, pr_number FROM pr_issue_links)
  SELECT p.repo_name, p.number, p.author, p.state,
         coalesce(rv.reviews, 0) AS reviews, p.ci_state,
         (lnk.pr_number IS NOT NULL) AS issue_linked,
         CASE
           WHEN lnk.pr_number IS NOT NULL                                          THEN 'issue-first planned'
           WHEN p.state = 'MERGED' AND coalesce(rv.reviews, 0) = 0 AND p.merged_at IS NOT NULL
                AND date_diff('hour', p.created_at, p.merged_at) < 24              THEN 'silent direct-to-main (proxy)'
           WHEN coalesce(rv.reviews, 0) >= 3                                       THEN 'review-heavy'
           WHEN p.ci_state = 'FAILURE'                                             THEN 'CI-heavy'
           WHEN p.state = 'CLOSED' AND p.merged_at IS NULL                         THEN 'abandoned request'
           WHEN coalesce(rv.reviews, 0) = 0                                        THEN 'PR-first drive-by'
           ELSE 'standard reviewed change'
         END AS archetype,
         'reviews=' || coalesce(rv.reviews, 0)
           || ' issue_linked=' || (lnk.pr_number IS NOT NULL)
           || ' ci=' || coalesce(p.ci_state, '∅')
           || ' state=' || p.state AS evidence
  FROM prs p
  LEFT JOIN rv  ON p.repo_name = rv.repo_name  AND p.number = rv.pr_number
  LEFT JOIN lnk ON p.repo_name = lnk.repo_name AND p.number = lnk.pr_number
  WHERE NOT p.is_bot;

-- ── Actor / process analysis (cat 5) ─────────────────────────────────────────

-- Unified per-actor activity across roles. Bots filtered. who-merges / who-fixes-CI
-- are unavailable (no mergedBy / no Actions actor in P1 — see catalog).
-- src: prs, pr_reviews, pr_comments, issues  [observed]
CREATE OR REPLACE VIEW actor_activity AS
  -- CAST(... AS VARCHAR): reviewer is inferred JSON when the reviews array is
  -- empty estate-wide; without the cast FULL JOIN USING(actor) tries to coerce
  -- author logins to JSON and dies. The cast makes the key type stable either way.
  WITH au AS (SELECT CAST(author AS VARCHAR) AS actor, count(*) AS prs_authored,
                     count(DISTINCT repo_name) AS repos
              FROM prs WHERE NOT is_bot AND author IS NOT NULL GROUP BY 1),
       rv AS (SELECT CAST(reviewer AS VARCHAR) AS actor, count(*) AS reviews,
                     count(*) FILTER (WHERE review_state = 'APPROVED') AS approvals
              FROM pr_reviews GROUP BY 1),
       cm AS (SELECT CAST(commenter AS VARCHAR) AS actor, count(*) AS comments
              FROM pr_comments GROUP BY 1),
       iss AS (SELECT CAST(author AS VARCHAR) AS actor, count(*) AS issues_opened
               FROM issues WHERE author IS NOT NULL GROUP BY 1)
  SELECT actor,
         coalesce(prs_authored, 0) AS prs_authored,
         coalesce(repos, 0)        AS repos,
         coalesce(reviews, 0)      AS reviews,
         coalesce(approvals, 0)    AS approvals,
         coalesce(comments, 0)     AS comments,
         coalesce(issues_opened, 0) AS issues_opened,
         coalesce(prs_authored, 0) + coalesce(reviews, 0) + coalesce(comments, 0) AS total_touches
  FROM au FULL JOIN rv USING (actor) FULL JOIN cm USING (actor) FULL JOIN iss USING (actor)
  WHERE actor IS NOT NULL
    AND NOT regexp_matches(lower(actor), 'bot|github-actions|dependabot|renovate|^app/')
  ORDER BY total_touches DESC;

-- Real ownership map: who dominates each repo's authorship. src: prs  [observed]
-- row_number() (not arg_max) so ties on PR count break deterministically by
-- author name — arg_max picks an arbitrary winner and breaks reproducibility.
CREATE OR REPLACE VIEW ownership_map AS
  WITH a AS (SELECT repo_name, author, count(*) c
             FROM prs WHERE NOT is_bot AND author IS NOT NULL GROUP BY 1, 2),
       t AS (SELECT repo_name, sum(c) AS tot, count(*) AS authors FROM a GROUP BY 1),
       ranked AS (SELECT repo_name, author, c,
                         row_number() OVER (PARTITION BY repo_name ORDER BY c DESC, author) AS rn
                  FROM a)
  SELECT r.repo_name,
         r.author                              AS top_author,
         r.c                                   AS top_author_prs,
         round(r.c::DOUBLE / t.tot, 2)         AS top_author_share,
         t.authors                             AS authors
  FROM ranked r JOIN t USING (repo_name)
  WHERE r.rn = 1;

-- Bus factor by repo: single-author and dominance risk. src: ownership_map  [inferred]
CREATE OR REPLACE VIEW bus_factor_repo AS
  SELECT repo_name, authors, top_author, top_author_share,
         CASE WHEN authors <= 1            THEN 'critical (single author)'
              WHEN top_author_share >= 0.8 THEN 'high (≥80% one author)'
              WHEN authors <= 2            THEN 'elevated (2 authors)'
              ELSE 'ok' END AS bus_factor_risk
  FROM ownership_map ORDER BY authors ASC, top_author_share DESC;

-- Bus factor by change class: which kinds of work depend on the fewest people.
-- src: change_class  [inferred]
CREATE OR REPLACE VIEW bus_factor_class AS
  SELECT change_class, count(DISTINCT author) AS authors, count(*) AS prs
  FROM change_class GROUP BY change_class ORDER BY prs DESC;

-- Reviewer concentration (HHI per repo): ~1.0 ⇒ one reviewer carries the repo.
-- src: pr_reviews  [observed]
CREATE OR REPLACE VIEW reviewer_concentration AS
  WITH r AS (SELECT repo_name, reviewer, count(*) c FROM pr_reviews GROUP BY 1, 2),
       t AS (SELECT repo_name, sum(c) tot, count(*) n FROM r GROUP BY 1)
  SELECT r.repo_name, t.n AS reviewers,
         round(sum((r.c::DOUBLE / t.tot) * (r.c::DOUBLE / t.tot)), 3) AS hhi
  FROM r JOIN t USING (repo_name) GROUP BY r.repo_name, t.n;

-- ── Repository health (cat 6) ────────────────────────────────────────────────

-- Per-repo health index. last_activity is a data-only timestamp; active-vs-
-- abandoned is decided by the renderer against --as-of. src: prs, pr_reviews  [observed]
CREATE OR REPLACE VIEW repo_health AS
  WITH base AS (
    SELECT repo_name,
           count(*) FILTER (WHERE NOT is_bot)                          AS prs,
           count(*) FILTER (WHERE state = 'MERGED' AND NOT is_bot)     AS merged,
           count(DISTINCT author) FILTER (WHERE NOT is_bot)            AS authors,
           max(greatest(coalesce(created_at, TIMESTAMP '1970-01-01'),
                        coalesce(merged_at,  TIMESTAMP '1970-01-01'))) AS last_activity,
           count(*) FILTER (WHERE ci_state IS NOT NULL)                AS ci_signals,
           count(*) FILTER (WHERE ci_state = 'FAILURE')                AS ci_failures
    FROM prs GROUP BY repo_name),
  rev AS (SELECT repo_name, count(DISTINCT pr_number) reviewed_prs FROM pr_reviews GROUP BY 1)
  SELECT b.repo_name, b.prs, b.merged, b.authors, b.last_activity,
         b.ci_signals, b.ci_failures,
         coalesce(rev.reviewed_prs, 0) AS reviewed_prs,
         round(coalesce(rev.reviewed_prs, 0)::DOUBLE / nullif(b.prs, 0), 2) AS reviewed_share,
         (b.authors <= 1)      AS single_owner,
         (b.ci_signals = 0)    AS no_ci
  FROM base b LEFT JOIN rev USING (repo_name);

-- ── Conway / socio-technical edge-lists (cat 9) ──────────────────────────────
-- These are the rows insights.rb exports as graph JSON + Mermaid.

-- actor → repo contribution. src: prs  [observed]
CREATE OR REPLACE VIEW edge_actor_repo AS
  SELECT author AS actor, repo_name, count(*) AS prs
  FROM prs WHERE NOT is_bot AND author IS NOT NULL
  GROUP BY author, repo_name;

-- reviewer → author (who reviews whom — the review communication graph).
-- src: pr_reviews, prs  [observed]
CREATE OR REPLACE VIEW edge_review_pair AS
  SELECT r.reviewer, p.author, count(*) AS weight
  FROM pr_reviews r JOIN prs p
    ON r.repo_name = p.repo_name AND r.pr_number = p.number
  WHERE p.author IS NOT NULL AND NOT p.is_bot AND r.reviewer <> p.author
  GROUP BY r.reviewer, p.author ORDER BY weight DESC;

-- commenter → author (the discussion graph). src: pr_comments, prs  [observed]
CREATE OR REPLACE VIEW edge_comment_pair AS
  SELECT c.commenter, p.author, count(*) AS weight
  FROM pr_comments c JOIN prs p
    ON c.repo_name = p.repo_name AND c.pr_number = p.number
  WHERE p.author IS NOT NULL AND NOT p.is_bot AND c.commenter <> p.author
  GROUP BY c.commenter, p.author ORDER BY weight DESC;

-- repo ↔ repo coupling inferred from shared authors (architectural coupling
-- proxy). Undirected (repo_a < repo_b), weighted by shared-actor count.
-- src: prs  [inferred]
CREATE OR REPLACE VIEW edge_repo_cochange AS
  WITH ar AS (SELECT DISTINCT author, repo_name
              FROM prs WHERE NOT is_bot AND author IS NOT NULL)
  SELECT a.repo_name AS repo_a, b.repo_name AS repo_b, count(*) AS shared_actors
  FROM ar a JOIN ar b ON a.author = b.author AND a.repo_name < b.repo_name
  GROUP BY a.repo_name, b.repo_name ORDER BY shared_actors DESC;

-- Boundary spanners: actors authoring across ≥2 repos (the connective tissue
-- whose departure fragments coordination). src: prs  [inferred]
CREATE OR REPLACE VIEW boundary_spanners AS
  SELECT author AS actor,
         count(DISTINCT repo_name)        AS repos,
         count(*)                         AS prs,
         string_agg(DISTINCT repo_name, '; ' ORDER BY repo_name) AS repo_list
  FROM prs WHERE NOT is_bot AND author IS NOT NULL
  GROUP BY author HAVING count(DISTINCT repo_name) >= 2
  ORDER BY repos DESC, prs DESC;

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PHASE 2 — harvest-expansion layer (Actions, releases, repo metadata,      ║
-- ║  PR/issue richness). Flips catalog entries from unavailable → observed.     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── GitHub Actions (cat 7) ───────────────────────────────────────────────────

-- Per-(repo, workflow) run reliability. failure_rate over decided runs only
-- (success/failure); duration median over the same to exclude stuck/cancelled
-- outliers. src: workflow_runs  [observed]
CREATE OR REPLACE VIEW workflow_reliability AS
  SELECT repo_name, name AS workflow,
         count(*)                                          AS runs,
         count(*) FILTER (WHERE conclusion = 'failure')    AS failures,
         count(*) FILTER (WHERE conclusion = 'cancelled')  AS cancelled,
         round(count(*) FILTER (WHERE conclusion = 'failure')::DOUBLE
               / nullif(count(*) FILTER (WHERE conclusion IN ('success','failure')), 0), 3) AS failure_rate,
         round(median(date_diff('second', run_started_at, updated_at))
               FILTER (WHERE conclusion IN ('success','failure')) / 60.0, 1) AS median_min
  FROM workflow_runs
  GROUP BY repo_name, name;

-- Per-repo Actions rollup. src: workflow_runs, workflows  [observed]
CREATE OR REPLACE VIEW actions_by_repo AS
  SELECT r.repo_name,
         count(DISTINCT r.workflow_id)                     AS active_workflows,
         count(*)                                          AS runs,
         count(*) FILTER (WHERE r.conclusion = 'failure')  AS failures,
         round(count(*) FILTER (WHERE r.conclusion = 'failure')::DOUBLE
               / nullif(count(*) FILTER (WHERE r.conclusion IN ('success','failure')), 0), 3) AS failure_rate
  FROM workflow_runs r
  GROUP BY r.repo_name;

-- Flaky workflows: both pass and fail with a mid-range failure rate. [inferred]
CREATE OR REPLACE VIEW flaky_workflows AS
  SELECT repo_name, workflow, runs, failure_rate
  FROM workflow_reliability
  WHERE runs >= 4 AND failure_rate > 0.1 AND failure_rate < 0.9
  ORDER BY failure_rate DESC, runs DESC;

-- Workflows whose name/path implies a deploy/release/publish gate (deploy
-- proxy until real deployments are harvested). src: workflows  [inferred]
CREATE OR REPLACE VIEW deploy_workflows AS
  SELECT DISTINCT repo_name, name AS workflow, path
  FROM workflows
  WHERE regexp_matches(lower(name), 'deploy|release|publish|\bcd\b|ship|production|pages')
     OR regexp_matches(lower(coalesce(path, '')), 'deploy|release|publish|/cd');

-- ── Releases / deploy signals (cat 2, 8) ─────────────────────────────────────
-- src: releases  [observed]
CREATE OR REPLACE VIEW releases_by_repo AS
  SELECT repo_name,
         count(*)                                  AS releases,
         count(*) FILTER (WHERE NOT prerelease)    AS final_releases,
         min(coalesce(published_at, created_at))   AS first_release,
         max(coalesce(published_at, created_at))   AS last_release
  FROM releases GROUP BY repo_name;

-- ── Branch-name signal (cat 4) ───────────────────────────────────────────────
-- Conventional branch prefix as an independent change signal. src: prs  [observed]
CREATE OR REPLACE VIEW branch_signal AS
  SELECT repo_name, number, head_ref,
         CASE WHEN regexp_matches(lower(coalesce(head_ref, '')),
                    '^(hotfix|release|feat|feature|fix|bug|chore|docs|refactor|ci|test|dependabot|renovate)/')
              THEN regexp_extract(lower(head_ref), '^([a-z]+)/', 1)
              ELSE 'none' END AS branch_prefix
  FROM prs WHERE NOT is_bot;

-- ── Merge gatekeepers (cat 5, who_merges) ────────────────────────────────────
-- src: prs.merged_by  [observed]
CREATE OR REPLACE VIEW merge_gatekeepers AS
  SELECT merged_by AS actor,
         count(*)                  AS merges,
         count(DISTINCT repo_name) AS repos,
         (lower(merged_by) LIKE '%bot%' OR merged_by LIKE 'app/%'
          OR lower(merged_by) IN ('github-actions','dependabot','renovate')) AS is_bot
  FROM prs WHERE state = 'MERGED' AND merged_by IS NOT NULL
  GROUP BY merged_by ORDER BY merges DESC;

-- ── Issue triage (cat 3, 5, 8) ───────────────────────────────────────────────
-- Time-to-first-response + reopen (rework) per issue. first response is the
-- earliest non-author comment. src: issues, issue_comments  [observed]
CREATE OR REPLACE VIEW issue_triage AS
  WITH fc AS (SELECT c.repo_name, c.issue_number, min(c.commented_at) AS first_response
              FROM issue_comments c
              JOIN issues i ON c.repo_name = i.repo_name AND c.issue_number = i.number
              WHERE c.commenter IS DISTINCT FROM i.author
              GROUP BY c.repo_name, c.issue_number)
  SELECT i.repo_name, i.number, i.author, i.created_at, i.closed_at, i.milestone,
         i.reopen_count,
         fc.first_response,
         date_diff('hour', i.created_at, fc.first_response) AS hours_to_first_response
  FROM issues i
  LEFT JOIN fc ON i.repo_name = fc.repo_name AND i.number = fc.issue_number;

-- Issue assignment / ownership (cat 5). src: issue_assignees  [observed]
CREATE OR REPLACE VIEW issue_assignment AS
  SELECT assignee AS actor,
         count(*)                  AS assigned,
         count(DISTINCT repo_name) AS repos
  FROM issue_assignees WHERE assignee IS NOT NULL
  GROUP BY assignee ORDER BY assigned DESC;

-- Reopen (rework) rate per repo. src: issues.reopen_count  [observed]
CREATE OR REPLACE VIEW reopen_summary AS
  SELECT repo_name,
         count(*)                                 AS issues,
         count(*) FILTER (WHERE reopen_count > 0)  AS reopened_issues,
         sum(reopen_count)                         AS reopen_events
  FROM issues GROUP BY repo_name;

-- Shared issue labels across repos: planned coordination vocabulary.
-- src: issue_labels  [observed]
CREATE OR REPLACE VIEW issue_label_coordination AS
  SELECT lower(label) AS label,
         count(DISTINCT repo_name) AS repos,
         count(*) AS issues,
         string_agg(DISTINCT repo_name, '; ' ORDER BY repo_name) AS repo_list
  FROM issue_labels
  WHERE label IS NOT NULL
  GROUP BY lower(label)
  HAVING count(DISTINCT repo_name) >= 2
  ORDER BY repos DESC, issues DESC, label;

-- Shared milestones across repos: explicit planning horizon reused by multiple
-- repositories. src: issues.milestone  [observed]
CREATE OR REPLACE VIEW issue_milestone_coordination AS
  SELECT milestone,
         count(DISTINCT repo_name) AS repos,
         count(*) AS issues,
         string_agg(DISTINCT repo_name, '; ' ORDER BY repo_name) AS repo_list
  FROM issues
  WHERE milestone IS NOT NULL AND milestone <> ''
  GROUP BY milestone
  HAVING count(DISTINCT repo_name) >= 2
  ORDER BY repos DESC, issues DESC, milestone;

-- People who coordinate issues across repos, regardless of whether they author,
-- respond to, or are assigned the issue. src: issues, issue_comments,
-- issue_assignees  [observed]
CREATE OR REPLACE VIEW issue_actor_coordination AS
  WITH responder AS (
    SELECT c.commenter AS actor, 'responder' AS role, c.repo_name, c.issue_number
    FROM issue_comments c
    JOIN issues i ON c.repo_name = i.repo_name AND c.issue_number = i.number
    WHERE c.commenter IS DISTINCT FROM i.author),
  actor_issue AS (
    SELECT author AS actor, 'author' AS role, repo_name, number AS issue_number
    FROM issues WHERE author IS NOT NULL
    UNION ALL
    SELECT assignee AS actor, 'assignee' AS role, repo_name, issue_number
    FROM issue_assignees WHERE assignee IS NOT NULL
    UNION ALL
    SELECT actor, role, repo_name, issue_number FROM responder)
  SELECT actor,
         count(DISTINCT repo_name) AS repos,
         count(DISTINCT repo_name || '#' || issue_number) AS issues,
         string_agg(DISTINCT role, ', ' ORDER BY role) AS roles,
         string_agg(DISTINCT repo_name, '; ' ORDER BY repo_name) AS repo_list
  FROM actor_issue
  WHERE actor IS NOT NULL
    AND NOT regexp_matches(lower(actor), 'bot|github-actions|dependabot|renovate|^app/')
  GROUP BY actor
  HAVING count(DISTINCT repo_name) >= 2
  ORDER BY repos DESC, issues DESC, actor;

-- Issue-to-PR closure links, including cross-repo links when the harvester has
-- the linked issue repository. Older caches lack issue_repo_name and fall back
-- to the PR repo. src: pr_issue_links  [observed]
CREATE OR REPLACE VIEW issue_closure_coordination AS
  SELECT coalesce(issue_repo_name, repo_name) AS issue_repo_name,
         issue_number,
         repo_name AS pr_repo_name,
         pr_number,
         (coalesce(issue_repo_name, repo_name) <> repo_name) AS cross_repo
  FROM pr_issue_links;

-- ── Repo metadata enrichment (cat 6) ─────────────────────────────────────────
-- repo_health + real language / default branch / archived / last push.
-- src: repo_health, repo_meta  [observed]
CREATE OR REPLACE VIEW repo_health_meta AS
  SELECT h.*,
         m.language,
         m.default_branch,
         m.archived,
         m.pushed_at,
         m.stargazers_count,
         m.open_issues_count
  FROM repo_health h
  LEFT JOIN repo_meta m ON h.repo_name = m.repo_name;

-- ── Gap closure (Phase 2.5): metrics that were unavailable in Phase 2 ─────────

-- who_fixes_ci: who triggers the success that follows a failure on a workflow
-- (a CI "recovery"). src: workflow_runs.actor/triggering_actor  [inferred]
CREATE OR REPLACE VIEW ci_fixers AS
  WITH seq AS (
    SELECT repo_name, workflow_id, name AS workflow, conclusion, run_started_at,
           coalesce(triggering_actor, actor) AS actor,
           lag(conclusion) OVER (PARTITION BY repo_name, workflow_id ORDER BY run_started_at) AS prev
    FROM workflow_runs
    WHERE conclusion IN ('success','failure'))
  SELECT actor,
         count(*)                                   AS recoveries,
         count(DISTINCT repo_name || '/' || workflow) AS workflows
  FROM seq
  WHERE conclusion = 'success' AND prev = 'failure' AND actor IS NOT NULL
    AND NOT regexp_matches(lower(actor), 'bot|github-actions|dependabot|renovate|^app/')
  GROUP BY actor ORDER BY recoveries DESC, actor;

-- who_owns_release: explicit release authors (observed), augmented by the
-- operators who run name-inferred deploy gates (inferred fallback).
-- src: releases.author, workflow_runs + deploy_workflows  [inferred]
CREATE OR REPLACE VIEW release_owners AS
  SELECT author AS actor, count(*) AS releases, count(DISTINCT repo_name) AS repos
  FROM releases WHERE author IS NOT NULL
  GROUP BY author ORDER BY releases DESC, actor;

CREATE OR REPLACE VIEW deploy_operators AS
  WITH dep AS (
    SELECT coalesce(r.triggering_actor, r.actor) AS actor, r.repo_name
    FROM workflow_runs r
    JOIN deploy_workflows d ON r.repo_name = d.repo_name AND r.name = d.workflow
    WHERE r.conclusion = 'success')
  SELECT actor, count(*) AS deploy_runs, count(DISTINCT repo_name) AS repos
  FROM dep WHERE actor IS NOT NULL
    AND NOT regexp_matches(lower(actor), 'bot|github-actions|dependabot|renovate|^app/')
  GROUP BY actor ORDER BY deploy_runs DESC, actor;

-- deploy_lead_lag: merge (to default branch) → next successful deploy-gate run.
-- PROXY: a name-inferred deploy gate is not a confirmed production deploy, and
-- runs are capped at the recent 100/repo. src: prs, repo_meta, workflow_runs  [proxy]
CREATE OR REPLACE VIEW deploy_lead_lag AS
  WITH merges AS (
    SELECT p.repo_name, p.number, p.merged_at
    FROM prs p JOIN repo_meta m ON p.repo_name = m.repo_name
    WHERE p.state = 'MERGED' AND p.merged_at IS NOT NULL AND NOT p.is_bot
      AND (p.base_ref = m.default_branch OR p.base_ref IS NULL)),
  deploys AS (
    SELECT r.repo_name, r.run_started_at
    FROM workflow_runs r
    JOIN deploy_workflows d ON r.repo_name = d.repo_name AND r.name = d.workflow
    WHERE r.conclusion = 'success' AND r.run_started_at IS NOT NULL)
  SELECT m.repo_name, m.number,
         date_diff('minute', m.merged_at, d.run_started_at) AS lag_minutes
  FROM merges m
  ASOF JOIN deploys d
    ON m.repo_name = d.repo_name AND d.run_started_at >= m.merged_at;

-- mttr_proxy: per workflow, time from a failing run to the next succeeding run
-- (pipeline recovery). PROXY: this is CI restore time, NOT production-incident
-- MTTR. src: workflow_runs  [proxy]
CREATE OR REPLACE VIEW mttr_proxy AS
  WITH fails AS (
    SELECT repo_name, workflow_id, name AS workflow, run_started_at
    FROM workflow_runs WHERE conclusion = 'failure' AND run_started_at IS NOT NULL),
  succ AS (
    SELECT repo_name, workflow_id, run_started_at
    FROM workflow_runs WHERE conclusion = 'success' AND run_started_at IS NOT NULL)
  SELECT f.repo_name, f.workflow,
         date_diff('minute', f.run_started_at, s.run_started_at) AS recovery_minutes
  FROM fails f
  ASOF JOIN succ s
    ON f.repo_name = s.repo_name AND f.workflow_id = s.workflow_id
       AND s.run_started_at >= f.run_started_at;

-- queue_vs_active_time: split PR cycle into waiting (open→first review) vs active
-- (first review→merge). PROXY: only covers reviewed, merged PRs; assumes review
-- marks the queue→active transition. src: prs, first_review_latency  [proxy]
CREATE OR REPLACE VIEW queue_active_split AS
  SELECT p.repo_name, p.number,
         frl.hours_to_first_review AS waiting_hours,
         date_diff('hour', p.created_at, p.merged_at) - frl.hours_to_first_review AS active_hours
  FROM prs p
  JOIN first_review_latency frl ON p.repo_name = frl.repo_name AND p.number = frl.number
  WHERE p.merged_at IS NOT NULL AND NOT p.is_bot
    AND frl.hours_to_first_review IS NOT NULL;
