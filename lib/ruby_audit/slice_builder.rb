# frozen_string_literal: true

require "fileutils"

module RubyAudit
  # Builds token-budget-aware context slices for LLM interrogation.
  #
  # Each slice is a self-contained Markdown file: audit brief + source files.
  # Sessions are planned so every slice fits within the token budget (default 32K)
  # with overhead reserved for system prompt and conversation history.
  #
  # Groups are auto-detected from the repo structure (namespaces, packages,
  # hotspot files). Sessions are numbered and named for easy reference.
  class SliceBuilder
    CHARS_PER_TOK = 4
    DEFAULT_BUDGET   = 32_000
    DEFAULT_OVERHEAD = 3_000 # system prompt + conversation history

    # Namespaces that get elevated priority (LLM/AI layer, security-relevant)
    PRIORITY_NAMESPACES = /\A(llm|ai|ml|openai|anthropic|admin|auth|security|payment)\z/i

    attr_reader :sessions

    def initialize(root:, audit_brief:, results:, out_dir:,
                   budget: DEFAULT_BUDGET, overhead: DEFAULT_OVERHEAD)
      @root     = Pathname.new(root).expand_path
      @brief    = Pathname.new(audit_brief)
      @results  = results
      @out_dir  = Pathname.new(out_dir).join("slices")
      @budget   = budget
      @overhead = overhead
      @brief_tokens = tok_file(@brief)
      @available    = budget - overhead - @brief_tokens
      @sessions = []
    end

    def build
      FileUtils.mkdir_p(@out_dir)

      groups = discover_groups
      @sessions = plan_sessions(groups)
      @sessions.each { |s| write_session(s) }
      @sessions
    end

    private

    # ── Group discovery ────────────────────────────────────────────────────────

    def discover_groups
      groups = []

      # Schema — anchor for every data-model session
      schema_files = glob("db/schema.rb") + glob("db/structure.sql")
      groups << group("schema", "Database schema", schema_files, priority: 1) if schema_files.any?

      # Models
      model_files = ruby_files("app/models")
      groups << group("models", "ActiveRecord models", model_files, priority: 2) if model_files.any?

      # Service namespaces — one group per subdirectory
      each_namespace("app/services") do |ns, files|
        groups << group("services-#{ns}", "#{ns} services", files, priority: ns_priority(ns))
      end

      # Controller namespaces
      each_namespace("app/controllers") do |ns, files|
        groups << group("controllers-#{ns}", "#{ns} controllers", files, priority: ns_priority(ns))
      end

      # Jobs and workers together (usually small, go in one group)
      async_files = ruby_files("app/jobs") + ruby_files("app/workers")
      groups << group("async", "Jobs + workers", async_files, priority: 5) if async_files.any?

      # Packages (one group per package)
      each_package do |pkg, files|
        groups << group("package-#{pkg}", "Package: #{pkg}", files, priority: 3)
      end

      # Top flog hotspots — each gets a dedicated single-file group
      top_hotspot_files.each_with_index do |entry, i|
        label = "Hotspot ##{i + 1}: #{entry[:method]}"
        groups << group("hotspot-#{i + 1}", label, [entry[:file]], priority: 0, hotspot: true)
      end

      # Compute token cost for every group
      groups.each { |g| g[:tokens] = g[:files].sum { |f| tok_file(f) } }

      # Drop empty groups
      groups.reject { |g| g[:tokens].zero? }
    end

    def group(name, label, files, priority: 5, hotspot: false)
      { name: name, label: label, files: files.map { |f| Pathname.new(f) },
        priority: priority, hotspot: hotspot, tokens: 0 }
    end

    # ── Session planning ───────────────────────────────────────────────────────
    # One session per group, ordered by priority. Oversized groups are split
    # into numbered parts. Hotspots always get their own session first.

    def plan_sessions(groups)
      sessions = []
      idx = 0

      ordered = groups.sort_by { |g| [g[:hotspot] ? 0 : 1, g[:priority], g[:name]] }

      ordered.each do |g|
        if g[:tokens] <= @available
          idx += 1
          sessions << make_session(idx, g[:name], g[:label], [g], g[:tokens])
        else
          # Split oversized group into parts that each fit within budget
          parts = split_group(g)
          parts.each_with_index do |part_files, part_idx|
            part_tokens = part_files.sum { |f| tok_file(f) }
            idx += 1
            part_label = parts.length > 1 ? "#{g[:label]} (part #{part_idx + 1}/#{parts.length})" : g[:label]
            part_name  = parts.length > 1 ? "#{g[:name]}-p#{part_idx + 1}" : g[:name]
            synthetic  = g.merge(files: part_files, tokens: part_tokens)
            sessions << make_session(idx, part_name, part_label, [synthetic], part_tokens)
          end
        end
      end

      sessions
    end

    def make_session(idx, name, label, groups, source_tokens)
      total = source_tokens + @brief_tokens + @overhead
      { idx: idx, name: format("session-%02d-%s", idx, name),
        label: label, groups: groups, tokens: total }
    end

    def split_group(group)
      parts = []
      current = []
      current_tokens = 0

      group[:files].each do |file|
        file_tokens = tok_file(file)
        if current_tokens + file_tokens > @available && current.any?
          parts << current
          current = [file]
          current_tokens = file_tokens
        else
          current << file
          current_tokens += file_tokens
        end
      end
      parts << current if current.any?
      parts
    end

    # ── Slice file writing ─────────────────────────────────────────────────────

    def write_session(session)
      out = @out_dir.join("#{session[:name]}.md")

      out.open("w") do |f|
        f.puts "# Audit Brief"
        f.puts ""
        f.puts @brief.read
        f.puts ""
        f.puts "---"
        f.puts ""
        f.puts "# Source: #{session[:label]}"
        f.puts ""

        session[:groups].each do |group|
          group[:files].each do |file|
            next unless file.exist?

            rel = file.relative_path_from(@root)
            f.puts "## `#{rel}`"
            f.puts "```ruby"
            f.puts file.read
            f.puts "```"
            f.puts ""
          end
        end
      end

      session[:path] = out
    end

    # ── Repo structure helpers ─────────────────────────────────────────────────

    def each_namespace(base)
      dir = @root.join(base)
      return unless dir.exist?

      dir.children.select(&:directory?).each do |ns_dir|
        ns    = ns_dir.basename.to_s
        files = ruby_files(dir.relative_path_from(@root).join(ns).to_s)
        yield ns, files if files.any?
      end
    end

    def each_package
      pkg_root = @root.join("packages")
      return unless pkg_root.exist?

      pkg_root.children.select(&:directory?).each do |pkg_dir|
        pkg   = pkg_dir.basename.to_s
        files = ruby_files("packages/#{pkg}")
        yield pkg, files if files.any?
      end
    end

    def ruby_files(rel)
      Dir.glob(@root.join(rel, "**", "*.rb")).map { |f| Pathname.new(f) }.select(&:file?)
    end

    def glob(*patterns)
      patterns.flat_map { |p| Dir.glob(@root.join(p)) }.map { |f| Pathname.new(f) }.select(&:file?)
    end

    def ns_priority(namespace)
      namespace.match?(PRIORITY_NAMESPACES) ? 2 : 5
    end

    # ── Flog hotspot extraction ────────────────────────────────────────────────

    def top_hotspot_files
      hotspots = @results.dig(:flog, :high_complexity) || []
      seen = {}

      hotspots.filter_map do |h|
        # flog method strings for named methods include the absolute path:
        #   "ClassName#method /abs/path/to/file.rb:start-end"
        next unless h[:method] =~ %r{\s+(/[^\s:]+\.rb):\d}

        file = Pathname.new(Regexp.last_match(1))
        next unless file.exist?
        next if seen[file.to_s]

        seen[file.to_s] = true
        { method: h[:method].split(%r{\s+/}).first.strip, file: file, score: h[:score] }
      end.first(3)
    end

    # ── Token counting ─────────────────────────────────────────────────────────

    def tok_file(path)
      return 0 unless path && File.exist?(path.to_s)

      File.size(path.to_s) / CHARS_PER_TOK
    end
  end
end
