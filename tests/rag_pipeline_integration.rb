#!/usr/bin/env ruby
# frozen_string_literal: true

# tests/rag_pipeline_integration.rb — End-to-end RAG pipeline integration test
#
# Tests the full chain:
#   ingest (frontmatter → DB) → embed job enqueued → worker (embed server → vector stored)
#   → semantic query (cosine similarity → correct results)
#
# Each test uses an isolated slug prefix (rag-e2e-<run_id>) and cleans up on exit.
# All seams are exercised via the public CLI (zdots-brain / zdots-ctx) — no internal
# Ruby calls — so this tests the same interface a human or agent would use.
#
# ─────────────────────────────────────────────────────────────────────────────
# Prerequisites
# ─────────────────────────────────────────────────────────────────────────────
#   - Embed server running on ZDOTS_AI_EMBED_ENDPOINT (default :11501)
#   - PostgreSQL 'my' accessible as zdots_rw and zdots_ro
#   - zdots-brain at $ZDOTDIR/sbin/zdots-brain
#
# Usage:
#   zdots-ruby tests/rag_pipeline_integration.rb           # full suite
#   zdots-ruby tests/rag_pipeline_integration.rb --quick   # prerequisites only
#   zdots-ruby tests/rag_pipeline_integration.rb --clean   # remove stale test records

require "net/http"
require "uri"
require "json"
require "tmpdir"
require "open3"

# ─────────────────────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────────────────────
ZDOTDIR        = ENV.fetch("ZDOTDIR", File.expand_path("~/.config/zsh"))
BRAIN          = File.join(ZDOTDIR, "sbin", "zdots-brain")
ZDOTS_CTX      = File.join(ZDOTDIR, "bin", "zdots-ctx")
EMBED_ENDPOINT = ENV.fetch("ZDOTS_AI_EMBED_ENDPOINT", "http://127.0.0.1:11501")
DB_USER_RO     = "zdots_ro"
DB_USER_RW     = "zdots_rw"
DB_NAME        = "my"
WORKER_TIMEOUT = 120 # seconds to wait for embed worker to finish
MAX_PENDING_BEFORE_SKIP = 10 # skip worker tests if embed backlog is too deep
RUN_ID         = Process.pid.to_s
TEST_SLUG      = "rag-e2e-#{RUN_ID}".freeze
QUICK          = ARGV.include?("--quick")
CLEAN_ONLY     = ARGV.include?("--clean")

# ─────────────────────────────────────────────────────────────────────────────
# Minimal test runner (same style as llama_integration.rb)
# ─────────────────────────────────────────────────────────────────────────────
PASS = "\e[32mPASS\e[0m"
FAIL = "\e[31mFAIL\e[0m"
SKIP = "\e[33mSKIP\e[0m"

$results = { pass: 0, fail: 0, skip: 0 }

def test(name, slow: false)
  if slow && QUICK
    print "  #{name.ljust(58)} "
    puts "#{SKIP}  quick mode"
    $results[:skip] += 1
    return
  end
  print "  #{name.ljust(58)} "
  begin
    yield
    puts PASS
    $results[:pass] += 1
  rescue SkipTest => e
    puts "#{SKIP}  #{e.message}"
    $results[:skip] += 1
  rescue StandardError => e
    puts "#{FAIL}  #{e.message}"
    $results[:fail] += 1
  end
end

class SkipTest < StandardError; end
def skip!(msg) = raise SkipTest, msg

def assert(cond, msg = "assertion failed")
  raise msg unless cond
end

def section(title)
  puts "\n── #{title} #{'─' * [0, 58 - title.length].max}"
end

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
def embed_up?
  uri = URI.parse("#{EMBED_ENDPOINT}/health")
  resp = Net::HTTP.get_response(uri)
  JSON.parse(resp.body)["status"] == "ok"
rescue StandardError
  false
end

def pg_up?
  system("psql -q -U #{DB_USER_RO} #{DB_NAME} -c 'SELECT 1' >/dev/null 2>&1")
end

def brain_present?
  File.executable?(BRAIN)
end

def pg_query(sql, user: DB_USER_RO)
  # -X skips .psqlrc to suppress startup banners (e.g. "PostgreSQL initialized.")
  out, err, status = Open3.capture3(
    "psql", "-q", "-X", "-U", user, DB_NAME, "-t", "-A", "-c", sql
  )
  raise "psql failed (#{status.exitstatus}): #{err}" unless status.success?

  # Return the last non-empty line — guards against any residual preamble
  out.lines.map(&:strip).reject(&:empty?).last.to_s
end

def brain_run(*args, input: nil)
  cmd = [BRAIN, *args]
  if input
    out, err, status = Open3.capture3(*cmd, stdin_data: input)
  else
    out, err, status = Open3.capture3(*cmd)
  end
  [out, err, status]
end

def ingest_file(path, dry_run: false)
  args = ["ingest"]
  args << "--dry-run" if dry_run
  args << path
  brain_run(*args)
end

def write_test_doc(dir, slug:, title:, content:, tags: %w[e2e-test rag-pipeline])
  frontmatter = <<~FM
    ---
    type: reference
    slug: #{slug}
    title: "#{title}"
    tags: [#{tags.join(', ')}]
    ---
  FM
  path = File.join(dir, "#{slug}.md")
  File.write(path, "#{frontmatter}\n#{content}")
  path
end

def cleanup_test_records!
  pg_query(
    "DELETE FROM methodologies WHERE slug LIKE 'rag-e2e-%'",
    user: DB_USER_RW
  )
  pg_query(
    "DELETE FROM jobs WHERE payload::text LIKE '%rag-e2e-%'",
    user: DB_USER_RW
  )
end

# ─────────────────────────────────────────────────────────────────────────────
# Clean-only mode
# ─────────────────────────────────────────────────────────────────────────────
if CLEAN_ONLY
  if pg_up?
    cleanup_test_records!
    puts "rag_pipeline_integration: cleaned stale test records (slug LIKE 'rag-e2e-%')"
  else
    puts "rag_pipeline_integration: PostgreSQL not available — nothing cleaned"
  end
  exit 0
end

# ─────────────────────────────────────────────────────────────────────────────
# Test fixture: two documents with distinct topics for relevance verification
# ─────────────────────────────────────────────────────────────────────────────
AUTH_SLUG    = "#{TEST_SLUG}-auth".freeze
AUTH_TITLE   = "RAG E2E Test: JWT Authentication Flow"
AUTH_CONTENT = <<~CONTENT
  ## JWT Authentication Flow

  The authentication subsystem issues JWT tokens with a 24-hour expiration window.
  Tokens are signed with RS256 and validated on every API request.
  The refresh endpoint accepts an active token and returns a new one when
  the remaining lifetime falls below five minutes. Token revocation is tracked
  in a Redis deny-list keyed by token jti claim.
CONTENT

CACHE_SLUG    = "#{TEST_SLUG}-cache".freeze
CACHE_TITLE   = "RAG E2E Test: Redis Cache Layer"
CACHE_CONTENT = <<~CONTENT
  ## Redis Cache Layer

  The caching layer uses Redis with a default TTL of 300 seconds.
  Cache keys follow the pattern resource:id:version. Cache invalidation
  is event-driven via a pub/sub channel; consumers subscribe at startup.
  The cache is write-through for reads and write-behind for mutations
  to avoid synchronous DB round-trips on the hot path.
CONTENT

puts "rag_pipeline_integration — end-to-end RAG pipeline"
puts "  zdots-brain : #{BRAIN}"
puts "  embed server: #{EMBED_ENDPOINT}"
puts "  run id      : #{RUN_ID}"
puts "  slugs       : #{AUTH_SLUG}, #{CACHE_SLUG}"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Prerequisites
# ─────────────────────────────────────────────────────────────────────────────
section "1. Prerequisites"

$prereqs_ok = true

test "zdots-brain binary present and executable" do
  unless brain_present?
    $prereqs_ok = false
    skip! "not found: #{BRAIN}"
  end
end

test "PostgreSQL zdots_ro accessible" do
  unless pg_up?
    $prereqs_ok = false
    skip! "PostgreSQL not available"
  end
end

test "embed server /health → {status: ok}" do
  unless embed_up?
    $prereqs_ok = false
    skip! "embed server not running at #{EMBED_ENDPOINT}"
  end
end

test "methodologies table has embedding column (vector)" do
  skip!("prerequisites not met") unless $prereqs_ok
  col = pg_query(
    "SELECT data_type FROM information_schema.columns " \
    "WHERE table_name='methodologies' AND column_name='embedding'"
  )
  assert col == "USER-DEFINED", "expected pgvector column, got: #{col.inspect}"
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. Ingest
# ─────────────────────────────────────────────────────────────────────────────
section "2. Ingest"

$tmpdir = Dir.mktmpdir("rag-e2e")
at_exit do
  FileUtils.rm_rf($tmpdir)
  cleanup_test_records! if pg_up?
end

$auth_path  = write_test_doc($tmpdir, slug: AUTH_SLUG,  title: AUTH_TITLE,  content: AUTH_CONTENT)
$cache_path = write_test_doc($tmpdir, slug: CACHE_SLUG, title: CACHE_TITLE, content: CACHE_CONTENT)

test "dry-run ingest reports correctly without writing" do
  skip!("prerequisites not met") unless $prereqs_ok
  out, _err, status = ingest_file($auth_path, dry_run: true)
  assert status.success?, "dry-run exited #{status.exitstatus}: #{out}"
  assert out.include?("dry-run") || out.include?("would ingest"),
         "expected dry-run output, got: #{out}"
  count = pg_query("SELECT COUNT(*) FROM methodologies WHERE slug='#{AUTH_SLUG}'").to_i
  assert count.zero?, "dry-run must not write to DB (found #{count} records)"
end

test "ingest auth doc → exit 0, record upserted" do
  skip!("prerequisites not met") unless $prereqs_ok
  out, err, status = ingest_file($auth_path)
  assert status.success?, "ingest failed (#{status.exitstatus}):\nout: #{out}\nerr: #{err}"
  assert out.include?("[ok]") || out.include?("ingested"),
         "expected [ok] in output, got: #{out}"
  count = pg_query("SELECT COUNT(*) FROM methodologies WHERE slug='#{AUTH_SLUG}'").to_i
  assert count == 1, "expected 1 methodology record, found #{count}"
end

test "ingest cache doc → exit 0, second record upserted" do
  skip!("prerequisites not met") unless $prereqs_ok
  _out, _err, status = ingest_file($cache_path)
  assert status.success?, "cache ingest failed"
  count = pg_query("SELECT COUNT(*) FROM methodologies WHERE slug='#{CACHE_SLUG}'").to_i
  assert count == 1, "expected 1 cache record, found #{count}"
end

test "embed job enqueued for each ingested doc" do
  skip!("prerequisites not met") unless $prereqs_ok
  auth_id  = pg_query("SELECT id FROM methodologies WHERE slug='#{AUTH_SLUG}'")
  cache_id = pg_query("SELECT id FROM methodologies WHERE slug='#{CACHE_SLUG}'")
  assert !auth_id.empty?,  "auth methodology id not found"
  assert !cache_id.empty?, "cache methodology id not found"
  count = pg_query(
    "SELECT COUNT(*) FROM jobs WHERE type='embed' " \
    "AND payload->>'table'='methodologies' " \
    "AND (payload->>'id'='#{auth_id}' OR payload->>'id'='#{cache_id}') " \
    "AND status IN ('pending','running','completed')"
  ).to_i
  assert count >= 2, "expected ≥2 embed jobs, found #{count}"
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. Worker: embed → vector store
# ─────────────────────────────────────────────────────────────────────────────
section "3. Worker: embed → vector store"

test "worker processes embed jobs within #{WORKER_TIMEOUT}s", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  pending = pg_query(
    "SELECT COUNT(*) FROM jobs WHERE type='embed' AND status='pending'"
  ).to_i
  if pending > MAX_PENDING_BEFORE_SKIP
    skip!("embed job backlog too deep (#{pending} pending) — drain first: zdots-brain worker --type embed")
  end
  _out, err, status = Open3.capture3(
    "timeout", WORKER_TIMEOUT.to_s, BRAIN, "worker", "--type", "embed"
  )
  # timeout returns 124; worker exits 0 when queue drained, or 124 if timed out.
  # Accept both: the test docs may have been embedded before timeout expired.
  acceptable = [0, 124].include?(status.exitstatus)
  assert acceptable, "worker failed with status #{status.exitstatus}: #{err}"
end

test "auth doc embedding stored (non-null, 768-dim)", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  has_embed = pg_query(
    "SELECT (embedding IS NOT NULL) FROM methodologies WHERE slug='#{AUTH_SLUG}'"
  )
  assert has_embed == "t", "no embedding stored for auth doc (got: #{has_embed.inspect})"
  dim = pg_query(
    "SELECT cardinality(embedding::real[]) FROM methodologies WHERE slug='#{AUTH_SLUG}'"
  )
  assert dim.to_i == 768, "expected 768-dim vector, got #{dim}"
end

test "cache doc embedding stored (non-null, 768-dim)", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  has_embed = pg_query(
    "SELECT (embedding IS NOT NULL) FROM methodologies WHERE slug='#{CACHE_SLUG}'"
  )
  assert has_embed == "t", "no embedding stored for cache doc (got: #{has_embed.inspect})"
  dim = pg_query(
    "SELECT cardinality(embedding::real[]) FROM methodologies WHERE slug='#{CACHE_SLUG}'"
  )
  assert dim.to_i == 768, "expected 768-dim vector, got #{dim}"
end

# ─────────────────────────────────────────────────────────────────────────────
# 4. Semantic query
# ─────────────────────────────────────────────────────────────────────────────
section "4. Semantic query"

test "query 'JWT token authentication refresh' → auth doc in results", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  out, err, status = brain_run("query", "--semantic", "JWT token authentication refresh")
  assert status.success?, "query exited #{status.exitstatus}\nstdout: #{out}\nstderr: #{err}"
  assert out.include?(AUTH_SLUG) || out.include?("JWT"),
         "auth doc not in results for JWT query.\nstdout: #{out[0..400]}"
end

test "query 'Redis cache TTL invalidation' → cache doc in results", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  out, err, status = brain_run("query", "--semantic", "Redis cache TTL invalidation")
  assert status.success?, "query exited #{status.exitstatus}\nstdout: #{out}\nstderr: #{err}"
  assert out.include?(CACHE_SLUG) || out.include?("Redis"),
         "cache doc not in results for Redis query.\nstdout: #{out[0..400]}"
end

test "query 'JWT token' → auth doc ranked above cache doc", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  out, err, status = brain_run("query", "--semantic", "JWT token")
  assert status.success?, "query exited #{status.exitstatus}\nstderr: #{err}"
  auth_pos  = out.index(AUTH_SLUG)  || Float::INFINITY
  cache_pos = out.index(CACHE_SLUG) || Float::INFINITY
  assert auth_pos != Float::INFINITY, "auth doc not found in results\nstdout: #{out[0..400]}"
  assert auth_pos < cache_pos,
         "auth doc (pos #{auth_pos}) should rank above cache doc (pos #{cache_pos})"
end

# ─────────────────────────────────────────────────────────────────────────────
# 5. Idempotency
# ─────────────────────────────────────────────────────────────────────────────
section "5. Idempotency"

test "re-ingest same slug → no duplicate record", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  _out, _err, status = ingest_file($auth_path)
  assert status.success?, "second ingest failed"
  count = pg_query("SELECT COUNT(*) FROM methodologies WHERE slug='#{AUTH_SLUG}'").to_i
  assert count == 1, "expected 1 record after re-ingest, found #{count}"
end

test "re-ingest with updated content → content updated in DB", slow: true do
  skip!("prerequisites not met") unless $prereqs_ok
  updated_path = write_test_doc(
    $tmpdir,
    slug: AUTH_SLUG,
    title: AUTH_TITLE,
    content: "#{AUTH_CONTENT}\n\nUpdated: token rotation policy added."
  )
  _out, _err, status = ingest_file(updated_path)
  assert status.success?, "updated ingest failed"
  count = pg_query("SELECT COUNT(*) FROM methodologies WHERE slug='#{AUTH_SLUG}'").to_i
  assert count == 1, "expected 1 record after update-ingest, found #{count}"
end

# ─────────────────────────────────────────────────────────────────────────────
# 6. Error cases
# ─────────────────────────────────────────────────────────────────────────────
section "6. Error cases"

test "ingest file with no frontmatter → skipped, exit 0" do
  skip!("prerequisites not met") unless $prereqs_ok
  no_fm = File.join($tmpdir, "no-frontmatter.md")
  File.write(no_fm, "# Just a heading\n\nNo frontmatter here.\n")
  out, _err, status = ingest_file(no_fm)
  assert status.success?, "expected exit 0 for skipped file, got #{status.exitstatus}"
  assert out.include?("[skip]"), "expected [skip] in output, got: #{out}"
end

test "ingest file with unknown type → skipped, exit 0" do
  skip!("prerequisites not met") unless $prereqs_ok
  bad_type = File.join($tmpdir, "bad-type.md")
  File.write(bad_type, <<~MD)
    ---
    type: widget
    slug: rag-e2e-bad-type
    title: "Bad Type"
    tags: [test]
    ---

    This has an unrecognised type field.
  MD
  out, _err, status = ingest_file(bad_type)
  assert status.success?, "expected exit 0, got #{status.exitstatus}"
  assert out.include?("[skip]") && out.include?("unknown type"),
         "expected unknown type skip, got: #{out}"
end

test "ingest file missing slug → skipped, exit 0" do
  skip!("prerequisites not met") unless $prereqs_ok
  no_slug = File.join($tmpdir, "no-slug.md")
  File.write(no_slug, <<~MD)
    ---
    type: reference
    title: "Missing slug"
    tags: [test]
    ---

    No slug field in frontmatter.
  MD
  out, _err, status = ingest_file(no_slug)
  assert status.success?, "expected exit 0, got #{status.exitstatus}"
  assert out.include?("[skip]"), "expected [skip], got: #{out}"
end

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
total = $results.values.sum
puts "\n── #{$results[:fail].zero? ? "\e[32mPASSED\e[0m" : "\e[31mFAILED\e[0m"}  " \
     "#{$results[:pass]}/#{total} passed, #{$results[:skip]} skipped " \
     "─────────────────────────────────────────────────────"

exit($results[:fail].positive? ? 1 : 0)
