# frozen_string_literal: true

module Zdots
  module Manifest
    SERVICES = {
      llama_cpp: {
        title: "llama.cpp (AI inference)",
        endpoint: ENV.fetch("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:11500"),
        start_cmd: "llama-ctl start",
        status_cmd: "llama-ctl status"
      },
      otelcol: {
        title: "otelcol-contrib (OTel collector)",
        endpoint: "http://127.0.0.1:4318",
        grpc_endpoint: "grpc://127.0.0.1:4317",
        start_cmd: "otel-collector start"
      },
      grafana: {
        title: "LGTM stack (Grafana/Loki/Tempo/Mimir)",
        url: "http://127.0.0.1:3000",
        credentials: "admin/admin",
        start_cmd: "local-ci start"
      },
      intelligence: {
        title: "Intelligence Suite (PostgreSQL)",
        database: "my",
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
