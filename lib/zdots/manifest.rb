# frozen_string_literal: true

require_relative "config"

module Zdots
  module Manifest
    SERVICES = {
      llama_cpp: {
        title: "llama.cpp (AI inference)",
        endpoint: Zdots::Config.ai_endpoint,
        start_cmd: "llama-ctl start",
        status_cmd: "llama-ctl status"
      },
      otelcol: {
        title: "otelcol-contrib (OTel collector)",
        endpoint: Zdots::Config.otlp_endpoint,
        grpc_endpoint: "grpc://#{Zdots::Config.get('ZDOTS_OTEL_HOST', '127.0.0.1')}:#{Zdots::Config.get('ZDOTS_OTEL_GRPC_PORT', '4317')}",
        start_cmd: "otel-collector start"
      },
      jaeger: {
        title: "Jaeger (distributed traces)",
        url: Zdots::Config.jaeger_endpoint,
        start_cmd: "zsvc start jaeger"
      },
      intelligence: {
        title: "Intelligence Suite (PostgreSQL)",
        database: Zdots::Config.database_url_default.sub(%r{\A.*/}, "").sub(/\?.*\z/, ""),
        manager: "zdots-ctx"
      }
    }.freeze

    TOOLS = [
      {
        name: "ctx_status",
        description: "Check connectivity and record counts of the Shell Brain.",
        mcp: true
      },
      {
        name: "ctx_query",
        description: "Search methodologies and lessons using full-text or semantic search.",
        params: { term: "string", semantic: "boolean" },
        mcp: true
      },
      {
        name: "ctx_hydrate",
        description: "Inject relevant context for task-specific AI engineering.",
        params: { tag: "string" },
        mcp: true
      },
      {
        name: "ctx_enqueue",
        description: "Drop high-latency work into the background Side-Effect Broker.",
        params: { type: "string", payload: "json" },
        mcp: true
      },
      {
        name: "living_docs",
        description: "Manually trigger the Living Docs synchronization pipeline.",
        mcp: true
      },
      {
        name: "ctx_add_methodology",
        description: "Save a new methodology to the Knowledge Layer.",
        params: { slug: "string", title: "string", content: "string" },
        mcp: true
      },
      {
        name: "ctx_add_lesson",
        description: "Save a new lesson to the Knowledge Layer.",
        params: { content: "string", context: "string" },
        mcp: true
      },
      {
        name: "ctx_capture",
        description: "Capture the current session residue into the Knowledge Layer. Requires ZDOTS_SESSION_ID.",
        mcp: true
      },
      {
        name: "ctx_semantic_search",
        description: "Semantic vector search across lessons and methodologies.",
        params: { term: "string" },
        mcp: true
      },
      {
        name: "ctx_jobs",
        description: "List pending and in-flight background jobs in the Knowledge Layer.",
        mcp: true
      },
      {
        name: "ctx_pipeline_events",
        description: "Summarize the structured pipeline event stream (Z-247): per-job_type started/succeeded/failed counts with error classes, plus the last 20 events. Reads the schema-validated JSONL — structural fields only, content-free by contract.",
        mcp: true
      }
    ].freeze

    class << self
      def services
        SERVICES
      end

      def tools
        TOOLS
      end

      def mcp_tools
        TOOLS.select { |t| t[:mcp] }
      end
    end
  end
end
