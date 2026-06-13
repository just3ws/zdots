# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "tempfile"
require "fileutils"
require "zdots"
require "zdots/wiki_exporter"
require "zdots/models/methodology"
require "zdots/models/lesson"

RSpec.describe Zdots::WikiExporter, :integration do
  let(:tmpdir) { Dir.mktmpdir }
  let(:db) { Zdots.db }

  before(:all) do
    # Connect to test database
    @db = Zdots.db
  rescue Sequel::DatabaseConnectionError => e
    skip "PostgreSQL unavailable (#{e.message})"
  end

  after { FileUtils.rm_rf(tmpdir) }

  around do |example|
    # Clear tables before/after each test
    begin
      Zdots.db[:methodologies].delete
      Zdots.db[:lessons].delete
      example.run
      Zdots.db[:methodologies].delete
      Zdots.db[:lessons].delete
    rescue StandardError
      example.run
    end
  end

  describe "#initialize" do
    it "accepts a database and wiki directory" do
      exporter = described_class.new(db, tmpdir)
      expect(exporter).to be_a(described_class)
    end

    it "uses default wiki_dir when not provided" do
      exporter = described_class.new(db)
      expect(exporter.instance_variable_get(:@wiki_dir)).to include("docs/wiki")
    end
  end

  describe "#run" do
    it "creates directory structure" do
      exporter = described_class.new(db, tmpdir)
      exporter.run

      expect(File.directory?(tmpdir)).to be true
      expect(File.directory?(File.join(tmpdir, "methodologies"))).to be true
      expect(File.directory?(File.join(tmpdir, "lessons"))).to be true
    end

    it "exports methodologies and lessons" do
      # Create test records
      Zdots.db[:methodologies].insert(
        slug: "test-methodology",
        title: "Test Methodology",
        content_enc: test_encrypt("Test content"),
        tags: Sequel.pg_array(["tag1", "tag2"]),
        updated_at: Time.now
      )

      Zdots.db[:lessons].insert(
        content_enc: test_encrypt("Lesson content"),
        context: "Test context",
        tags: Sequel.pg_array(["tag3"]),
        source_trace_id: "abc123def456ghi",
        created_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      exporter.run

      # Verify files exist
      expect(File.exist?(File.join(tmpdir, "methodologies", "test-methodology.md"))).to be true
      expect(File.exist?(File.join(tmpdir, "lessons", "abc123def456.md"))).to be true
      expect(File.exist?(File.join(tmpdir, "INDEX.md"))).to be true
    end

    it "produces idempotent output (safe to re-run)" do
      # Create test record
      Zdots.db[:methodologies].insert(
        slug: "idempotent-test",
        title: "Idempotent Test",
        content_enc: test_encrypt("Stable content"),
        tags: pg_text_array([]),
        updated_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      exporter.run

      content1 = File.read(File.join(tmpdir, "methodologies", "idempotent-test.md"))
      index1 = File.read(File.join(tmpdir, "INDEX.md"))

      # Run again
      exporter.run

      content2 = File.read(File.join(tmpdir, "methodologies", "idempotent-test.md"))
      index2 = File.read(File.join(tmpdir, "INDEX.md"))

      expect(content1).to eq(content2)
      expect(index1).to eq(index2)
    end
  end

  describe "#export_methodologies" do
    it "returns array of exported hashes with slug, title, tags, type" do
      Zdots.db[:methodologies].insert(
        slug: "method-1",
        title: "Method One",
        content_enc: test_encrypt("Content 1"),
        tags: Sequel.pg_array(["alpha"]),
        updated_at: Time.now
      )

      Zdots.db[:methodologies].insert(
        slug: "method-2",
        title: "Method Two",
        content_enc: test_encrypt("Content 2"),
        tags: Sequel.pg_array(["beta", "gamma"]),
        updated_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "methodologies"))

      result = exporter.export_methodologies

      expect(result.length).to eq(2)
      expect(result[0]).to include(slug: "method-1", title: "Method One", type: "methodology")
      expect(result[0][:tags]).to eq(["alpha"])
      expect(result[1]).to include(slug: "method-2", title: "Method Two")
      expect(result[1][:tags]).to include("beta", "gamma")
    end

    it "writes markdown files with YAML frontmatter" do
      now = Time.now
      Zdots.db[:methodologies].insert(
        slug: "fm-test",
        title: "Frontmatter Test",
        content_enc: test_encrypt("Body content here"),
        tags: Sequel.pg_array(["test"]),
        updated_at: now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "methodologies"))

      exporter.export_methodologies

      file_path = File.join(tmpdir, "methodologies", "fm-test.md")
      content = File.read(file_path)

      # Verify frontmatter
      expect(content).to start_with("---\n")
      expect(content).to include("type: methodology")
      expect(content).to include("slug: fm-test")
      expect(content).to include("title: Frontmatter Test")
      expect(content).to include("tags:\n- test")
      expect(content).to match(/updated_at:\s*['"]?#{Regexp.escape(now.iso8601)}['"]?/)
      expect(content).to include("\nBody content here\n")
    end

    it "handles nil/empty tags gracefully" do
      Zdots.db[:methodologies].insert(
        slug: "no-tags",
        title: "No Tags",
        content_enc: test_encrypt("Content"),
        tags: pg_text_array([]),
        updated_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "methodologies"))

      result = exporter.export_methodologies

      expect(result[0][:tags]).to eq([])

      file_path = File.join(tmpdir, "methodologies", "no-tags.md")
      content = File.read(file_path)
      expect(content).to include("tags: []")
    end
  end

  describe "#export_lessons" do
    it "returns array of exported hashes" do
      now = Time.now
      Zdots.db[:lessons].insert(
        content_enc: test_encrypt("Lesson 1 content"),
        context: "Context 1",
        tags: Sequel.pg_array(["lesson"]),
        source_trace_id: "trace123abc456def",
        created_at: now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "lessons"))

      result = exporter.export_lessons

      expect(result.length).to eq(1)
      expect(result[0][:slug]).to eq("trace123abc4")  # First 12 chars [0..11] of trace ID
      expect(result[0][:title]).to eq("Context 1")
      expect(result[0][:type]).to eq("lesson")
      expect(result[0][:tags]).to eq(["lesson"])
    end

    it "derives slug from source_trace_id when available" do
      Zdots.db[:lessons].insert(
        content_enc: test_encrypt("Content"),
        context: "Test",
        tags: pg_text_array([]),
        source_trace_id: "mytraceabc123def",
        created_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "lessons"))

      result = exporter.export_lessons

      expect(result[0][:slug]).to eq("mytraceabc12")  # First 12 chars
    end

    it "falls back to SHA1 hash of ID when no source_trace_id" do
      lesson_id = SecureRandom.uuid
      Zdots.db[:lessons].insert(
        id: lesson_id,
        content_enc: test_encrypt("Content"),
        context: "Context",
        tags: pg_text_array([]),
        source_trace_id: nil,
        created_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "lessons"))

      result = exporter.export_lessons

      # Slug should be first 12 chars of SHA1 hash
      expected_hash = Digest::SHA1.hexdigest(lesson_id)[0..11]
      expect(result[0][:slug]).to eq(expected_hash)
    end

    it "writes markdown files with lesson-specific frontmatter" do
      now = Time.now
      Zdots.db[:lessons].insert(
        content_enc: test_encrypt("Lesson body"),
        context: "Deployment context",
        tags: Sequel.pg_array(["ops", "deploy"]),
        source_trace_id: "op123def456abc",
        created_at: now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "lessons"))

      exporter.export_lessons

      file_path = File.join(tmpdir, "lessons", "op123def456a.md")
      content = File.read(file_path)

      expect(content).to include("type: lesson")
      expect(content).to include("context: Deployment context")
      expect(content).to match(/created_at:\s*['"]?#{Regexp.escape(now.iso8601)}['"]?/)
      expect(content).to include("tags:\n- ops\n- deploy")
      expect(content).to include("\nLesson body\n")
    end

    it "uses context as title when available" do
      Zdots.db[:lessons].insert(
        content_enc: test_encrypt("Content"),
        context: "My custom context",
        tags: pg_text_array([]),
        source_trace_id: "abc123def456ghi",
        created_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "lessons"))

      result = exporter.export_lessons

      expect(result[0][:title]).to eq("My custom context")
    end

    it "falls back to generic title when context is nil" do
      Zdots.db[:lessons].insert(
        content_enc: test_encrypt("Content"),
        context: nil,
        tags: pg_text_array([]),
        source_trace_id: "fallback123abc",
        created_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "lessons"))

      result = exporter.export_lessons

      expect(result[0][:title]).to eq("Lesson fallback123a")
    end
  end

  describe "#write_index" do
    it "generates INDEX.md with methodology and lesson tables" do
      methodologies = [
        { slug: "m1", title: "Method One", tags: ["tag1"], type: "methodology" },
        { slug: "m2", title: "Method Two", tags: ["tag2", "tag3"], type: "methodology" }
      ]

      lessons = [
        { slug: "l1", title: "Lesson One", tags: ["tag3"], type: "lesson" },
        { slug: "l2", title: "Lesson Two", tags: [], type: "lesson" }
      ]

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(tmpdir)

      exporter.write_index(methodologies, lessons)

      index_path = File.join(tmpdir, "INDEX.md")
      content = File.read(index_path)

      # Verify structure
      expect(content).to include("# Wiki Index")
      expect(content).to include("## Methodologies (2)")
      expect(content).to include("## Lessons (2)")
      expect(content).to include("## Tags")

      # Verify tables
      expect(content).to include("[Method One](methodologies/m1.md)")
      expect(content).to include("[Method Two](methodologies/m2.md)")
      expect(content).to include("[Lesson One](lessons/l1.md)")
      expect(content).to include("[Lesson Two](lessons/l2.md)")

      # Verify tag cloud
      expect(content).to include("- **tag1** (1)")
      expect(content).to include("- **tag2** (1)")
      expect(content).to include("- **tag3** (2)")
    end

    it "handles empty methodology/lesson lists" do
      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(tmpdir)

      exporter.write_index([], [])

      index_path = File.join(tmpdir, "INDEX.md")
      content = File.read(index_path)

      expect(content).to include("## Methodologies (0)")
      expect(content).to include("_(none)_")
      expect(content).to include("## Lessons (0)")
      expect(content).to include("_(none)_")
    end

    it "escapes markdown special characters in titles" do
      methodologies = [
        { slug: "m1", title: "Method [with] *special* chars", tags: [], type: "methodology" }
      ]

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(tmpdir)

      exporter.write_index(methodologies, [])

      index_path = File.join(tmpdir, "INDEX.md")
      content = File.read(index_path)

      # Title should be escaped in markdown
      expect(content).to include("Method \\[with\\]")
    end

    it "includes generated footer" do
      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(tmpdir)

      exporter.write_index([], [])

      index_path = File.join(tmpdir, "INDEX.md")
      content = File.read(index_path)

      expect(content).to include("---")
      expect(content).to include("Generated by `Zdots::WikiExporter`")
    end
  end

  describe "encryption and decryption" do
    it "correctly decrypts methodology content" do
      original_content = "This is encrypted methodology content"
      Zdots.db[:methodologies].insert(
        slug: "encrypt-test",
        title: "Encryption Test",
        content_enc: test_encrypt(original_content),
        tags: pg_text_array([]),
        updated_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "methodologies"))

      exporter.export_methodologies

      file_path = File.join(tmpdir, "methodologies", "encrypt-test.md")
      content = File.read(file_path)

      expect(content).to include(original_content)
    end

    it "correctly decrypts lesson content" do
      original_content = "This is encrypted lesson content"
      Zdots.db[:lessons].insert(
        content_enc: test_encrypt(original_content),
        context: "Test",
        tags: pg_text_array([]),
        source_trace_id: "test123abc456def",
        created_at: Time.now
      )

      exporter = described_class.new(db, tmpdir)
      FileUtils.mkdir_p(File.join(tmpdir, "lessons"))

      exporter.export_lessons

      file_path = File.join(tmpdir, "lessons", "test123abc45.md")
      content = File.read(file_path)

      expect(content).to include(original_content)
    end
  end

  # Helper to encrypt content for test fixtures
  def test_encrypt(plaintext)
    Zdots.db.get(
      Sequel.function(:pgp_sym_encrypt, plaintext, Zdots::Crypto::KeyStore.current_key)
    )
  end

  # Helper to handle empty arrays in PostgreSQL
  def pg_text_array(arr)
    if arr && arr.any?
      Sequel.pg_array(arr)
    else
      # Use Sequel's literal SQL for empty text array
      Sequel.lit("ARRAY[]::text[]")
    end
  end
end
