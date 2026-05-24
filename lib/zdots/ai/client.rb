# frozen_string_literal: true

module Zdots
  module AI
    class LocalityError < StandardError; end

    def self.client
      assert_local!
      @client ||= build_client
    end

    def self.reset!
      @client = nil
    end

    def self.endpoint
      ENV.fetch("ZDOTS_AI_ENDPOINT", "http://127.0.0.1:8080")
    end

    def self.assert_local!
      mode = ENV.fetch("ZDOTS_AI_MODE", "local")
      if mode == "none"
        audit_log("ai_gate_triggered", "tool=zdots mode=none")
        raise LocalityError, "AI unavailable (ZDOTS_AI_MODE=none)"
      end
      return if mode == "cloud"
      unless local_endpoint?(endpoint)
        audit_log("endpoint_assertion_fail", "endpoint=#{endpoint} mode=#{mode}")
        raise LocalityError, "SECURITY: AI endpoint is not local: #{endpoint}"
      end
      audit_log("endpoint_assertion_pass", "endpoint=#{endpoint} mode=#{mode}")
    end

    class << self
      private

      def build_client
        require "ruby_llm"
        ep = endpoint
        RubyLLM.configure do |c|
          c.openai_api_key         = "local"
          c.openai_api_base        = "#{ep}/v1"
          c.openai_use_system_role = true
          c.default_model          = "local"
          c.request_timeout        = 90
        end
        Connection.new
      end

      def local_endpoint?(url)
        require "uri"
        host = URI.parse(url).host.to_s
        host == "localhost" ||
          host == "::1" ||
          host.match?(/\A127\./) ||
          host.match?(/\A10\./) ||
          host.match?(/\A172\.(1[6-9]|2[0-9]|3[01])\./) ||
          host.match?(/\A192\.168\./)
      rescue URI::InvalidURIError
        false
      end

      def audit_log(event, detail = "")
        return unless RbConfig::CONFIG["host_os"].include?("darwin")
        type = case event
               when /_fail|_triggered|_violation/ then "fault"
               when /_pass|_redacted/             then "info"
               else "default"
               end
        system(
          "/usr/bin/log", "emit",
          "--subsystem", "com.zdots",
          "--category",  "phi-boundary",
          "--type",      type,
          "--public",
          "event=#{event} #{detail}",
          exception: false
        )
      end
    end

    # Thin adapter over the RubyLLM 1.15 module-level API.
    class Connection
      CALL_OPTS = { provider: "openai", assume_model_exists: true }.freeze

      def chat(model:, messages:, temperature:)
        c = RubyLLM.chat(**CALL_OPTS.merge(model: model))
        c.with_temperature(temperature) if temperature
        sys  = messages.find { |m| m[:role] == "system" }
        user = messages.find { |m| m[:role] == "user" }
        c.with_instructions(sys[:content]) if sys
        c.ask(user[:content])
      end

      def embed(model:, input:)
        RubyLLM.embed(input, **CALL_OPTS.merge(model: model))
      end
    end
  end
end
