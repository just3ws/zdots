# frozen_string_literal: true

require "open3"
require "json"
require "tmpdir"
require "pathname"

module RubyAudit
  # Runs each static analysis tool against a target directory.
  # All runners return a Hash: { ok:, output:, raw: }
  module Runners
    ZDOTS         = Pathname.new(__dir__).parent.parent.freeze
    AUDIT_GEMFILE = ZDOTS.join("etc", "ruby-audit", "Gemfile").freeze

    def self.run_cmd(*cmd, cwd: nil)
      # Always run analyzers through the isolated audit Gemfile, not the target
      # project's bundle and not zdots' main bundle.
      env  = { "BUNDLE_GEMFILE" => AUDIT_GEMFILE.to_s }
      opts = cwd ? { chdir: cwd } : {}
      stdout, stderr, status = Open3.capture3(env, *cmd, opts)
      { ok: status.success?, stdout: stdout, stderr: stderr, exit: status.exitstatus }
    end

    # ── bundler-audit ─────────────────────────────────────────────────────────

    def self.bundler_audit(root)
      lockfile = File.join(root, "Gemfile.lock")
      return { ok: false, output: [], raw: nil, skipped: "no Gemfile.lock" } unless File.exist?(lockfile)

      result = run_cmd("bundle", "exec", "bundler-audit", "check", "--format", "json",
                       "--gemfile-lock", lockfile, cwd: ZDOTS.to_s)
      raw = JSON.parse(result[:stdout]) rescue nil
      vulns = raw&.dig("results") || []
      { ok: vulns.empty?, output: vulns, raw: raw }
    rescue => e
      { ok: false, output: [], raw: nil, error: e.message }
    end

    # ── rubocop ───────────────────────────────────────────────────────────────

    def self.rubocop(root, ruby_version: nil)
      cfg = write_rubocop_config(root, ruby_version)
      result = run_cmd(
        "bundle", "exec", "rubocop",
        "--config", cfg,
        "--format", "json",
        "--no-color",
        root,
        cwd: ZDOTS.to_s
      )
      raw = JSON.parse(result[:stdout]) rescue nil
      files    = raw&.dig("files")   || []
      offenses = files.flat_map { |f| f["offenses"].map { |o| o.merge("path" => f["path"]) } }
      summary  = raw&.dig("summary") || {}
      { ok: summary["offense_count"].to_i.zero?, output: offenses, summary: summary, raw: raw }
    rescue => e
      { ok: false, output: [], raw: nil, error: e.message }
    ensure
      File.delete(cfg) if cfg && File.exist?(cfg)
    end

    # ── brakeman ─────────────────────────────────────────────────────────────

    def self.brakeman(root, rails_version: nil)
      gemfile = File.join(root, "Gemfile")
      unless File.exist?(gemfile)
        return { ok: true, output: [], raw: nil, skipped: "no Gemfile (not a Rails app)" }
      end

      rails_flag = rails_version&.start_with?("5") ? ["--rails5"] :
                   rails_version&.start_with?("6") ? ["--rails6"] : []

      result = run_cmd(
        "bundle", "exec", "brakeman",
        *rails_flag,
        "--no-progress", "--quiet",
        "--format", "json",
        "--path", root,
        cwd: ZDOTS.to_s
      )
      raw      = JSON.parse(result[:stdout]) rescue nil
      warnings = raw&.dig("warnings") || []
      { ok: warnings.none? { |w| %w[High Medium].include?(w["confidence"]) },
        output: warnings, raw: raw }
    rescue => e
      { ok: false, output: [], raw: nil, error: e.message }
    end

    # ── reek ──────────────────────────────────────────────────────────────────

    def self.reek(root)
      result = run_cmd(
        "bundle", "exec", "reek",
        "--format", "json",
        "--no-color",
        root,
        cwd: ZDOTS.to_s
      )
      raw   = JSON.parse(result[:stdout]) rescue []
      smells = Array(raw)
      { ok: smells.empty?, output: smells, raw: raw }
    rescue => e
      { ok: false, output: [], raw: nil, error: e.message }
    end

    # ── flog (complexity) ────────────────────────────────────────────────────

    def self.flog(root)
      result = run_cmd(
        "bundle", "exec", "flog",
        "--all", "--continue", "--group",
        root,
        cwd: ZDOTS.to_s
      )
      entries = parse_flog(result[:stdout])
      threshold = 30
      high = entries.select { |e| e[:score] >= threshold }
      { ok: high.empty?, output: entries, high_complexity: high, raw: result[:stdout] }
    rescue => e
      { ok: false, output: [], raw: nil, error: e.message }
    end

    # ── flay (duplication) ───────────────────────────────────────────────────

    def self.flay(root)
      result = run_cmd(
        "bundle", "exec", "flay",
        "--mass", "20",
        root,
        cwd: ZDOTS.to_s
      )
      matches = parse_flay(result[:stdout])
      { ok: matches.empty?, output: matches, raw: result[:stdout] }
    rescue => e
      { ok: false, output: [], raw: nil, error: e.message }
    end

    # ── helpers ───────────────────────────────────────────────────────────────

    def self.write_rubocop_config(root, ruby_version)
      cfg_path = File.join(Dir.tmpdir, "ruby_audit_rubocop_#{Process.pid}.yml")
      target_version = ruby_version&.then { |v| v[/\A\d+\.\d+/] } || "2.7"

      # Start from a clean AllCops config; do not inherit the target repo's .rubocop.yml
      # so we get consistent results regardless of what the target project configures.
      File.write(cfg_path, <<~YAML)
        AllCops:
          TargetRubyVersion: #{target_version}
          NewCops: disable
          DisabledByDefault: true
          SuggestExtensions: false
          Exclude:
            - 'vendor/**/*'
            - 'tmp/**/*'
            - 'log/**/*'
            - 'node_modules/**/*'
            - 'public/assets/**/*'

        Metrics/MethodLength:
          Enabled: true
          Max: 20

        Metrics/ClassLength:
          Enabled: true
          Max: 300

        Metrics/CyclomaticComplexity:
          Enabled: true
          Max: 10

        Metrics/AbcSize:
          Enabled: true
          Max: 30

        Metrics/PerceivedComplexity:
          Enabled: true
          Max: 8

        Security/Eval:
          Enabled: true

        Security/JSONLoad:
          Enabled: true

        Security/MarshalLoad:
          Enabled: true

        Security/Open:
          Enabled: true

        Security/YAMLLoad:
          Enabled: true

        Style/FrozenStringLiteralComment:
          Enabled: true
      YAML

      cfg_path
    end

    def self.parse_flog(output)
      entries = []
      output.each_line do |line|
        next unless line =~ /^\s*([\d.]+):\s+(.+)$/

        score  = Regexp.last_match(1).to_f
        method = Regexp.last_match(2).strip
        entries << { score: score, method: method } unless method == "main#none"
      end
      entries.sort_by { |e| -e[:score] }
    end

    def self.parse_flay(output)
      matches = []
      current = nil
      output.each_line do |line|
        if line =~ /^(\d+)\) .+, mass = (\d+)/
          matches << current if current
          current = { id: Regexp.last_match(1).to_i, mass: Regexp.last_match(2).to_i, locations: [] }
        elsif current && line =~ /^\s+(.+):(\d+)/
          current[:locations] << { file: Regexp.last_match(1).strip, line: Regexp.last_match(2).to_i }
        end
      end
      matches << current if current
      matches
    end
  end
end
