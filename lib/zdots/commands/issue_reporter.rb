# frozen_string_literal: true

require "json"

module Zdots
  module Commands
    class IssueReporter
      attr_reader :options

      def initialize(options)
        @options = options
      end

      # Map old terminology to new feedback types
      def self.report_type_from_old(old_type)
        case old_type
        when "bug"       then "error"
        when "question"  then "friction"  # questions indicate friction/confusion
        when "request"   then "request"
        else
          "friction"
        end
      end

      # Map priorities to severities
      def self.severity_from_priority(priority)
        case priority
        when "high"   then "high"
        when "medium" then "medium"
        when "low"    then "low"
        else
          "medium"
        end
      end

      def report
        # Try to store in database
        if db_available?
          store_in_db
        else
          # Fallback to JSONL
          store_in_jsonl
        end
      end

      private

      def db_available?
        Zdots.db != nil
      rescue StandardError
        false
      end

      def store_in_db
        report_type = options[:type] || "error"
        severity = options[:severity] || "medium"
        title = options[:title] || "Issue"
        description = options[:description] || ""
        reporter = options[:reporter] || ENV["USER"] || "unknown"
        trace_id = options[:trace_id] || ENV["ZDOTS_TRACE_ID"]
        environment = options[:environment] || capture_environment

        feedback = Models::OperationalFeedback.create_or_deduplicate(
          report_type: report_type,
          severity: severity,
          title: title,
          description: description,
          reporter: reporter,
          trace_id: trace_id,
          environment: environment,
          status: "open",
          tags: options[:tags] || []
        )

        { id: feedback.id, status: "stored_in_db" }
      end

      def store_in_jsonl
        issues_dir = File.join(ENV["ZDOTDIR"] || File.expand_path("~/.config/zsh"), "var")
        FileUtils.mkdir_p(issues_dir)

        entry = {
          ts: Time.now.utc.iso8601,
          type: options[:type] || "error",
          severity: options[:severity] || "medium",
          priority: options[:priority] || "medium",
          trace: options[:trace_id] || ENV["ZDOTS_TRACE_ID"] || "",
          title: options[:title] || "Issue",
          description: options[:description] || "",
          reporter: options[:reporter] || ENV["USER"] || "unknown"
        }

        File.open(File.join(issues_dir, "agent-issues.jsonl"), "a") do |f|
          f.puts(entry.to_json)
        end

        { status: "stored_in_jsonl" }
      end

      def capture_environment
        {
          machine: ENV["HOSTNAME"] || `hostname -s`.strip,
          user: ENV["USER"] || "unknown",
          zdots_version: read_zdots_version,
          ai_mode: ENV["ZDOTS_AI_MODE"] || "local",
          services_running: detect_running_services,
          shell: ENV["SHELL"] || "unknown"
        }
      end

      def read_zdots_version
        # Try to read from git
        version_file = File.join(ENV["ZDOTDIR"] || File.expand_path("~/.config/zsh"), ".git/HEAD")
        if File.exist?(version_file)
          branch = File.read(version_file).strip.gsub("ref: refs/heads/", "")
          "#{branch}-#{Time.now.strftime('%Y-%m-%d')}"
        else
          Time.now.strftime("%Y-%m-%d")
        end
      rescue StandardError
        "unknown"
      end

      def detect_running_services
        services = []
        %w[llama embed otel colima].each do |svc|
          # Check if service is running via pgrep or ps
          running = system("pgrep -f '#{svc}' > /dev/null 2>&1")
          services << svc if running
        end
        services
      rescue StandardError
        []
      end
    end
  end
end
