# frozen_string_literal: true

module Zdots
  # Single-source-of-truth config reader for etc/defaults.env (ADR-0005).
  # Precedence: process ENV > etc/defaults.env > explicit fallback.
  module Config
    DEFAULTS_RE = /\A\$\{([A-Za-z_][A-Za-z0-9_]*):-([^$`}]*)\}\z/

    class << self
      def defaults
        @defaults ||= load_defaults
      end

      def reset!
        @defaults = nil
      end

      def get(key, fallback = nil)
        v = ENV[key]
        return v if v && !v.empty?

        d = defaults[key]
        return d if d && !d.empty?

        fallback
      end

      def ai_endpoint
        get("ZDOTS_AI_ENDPOINT", "http://#{get('ZDOTS_AI_HOST', '127.0.0.1')}:#{get('ZDOTS_AI_PORT', '11500')}")
      end

      def embed_endpoint
        get("ZDOTS_AI_EMBED_ENDPOINT", "http://#{get('ZDOTS_AI_HOST', '127.0.0.1')}:#{get('ZDOTS_AI_EMBED_PORT', '11501')}")
      end

      def otlp_endpoint
        get("ZDOTS_OTLP_ENDPOINT", get("ZDOTS_OTEL_ENDPOINT", "http://127.0.0.1:#{get('ZDOTS_OTEL_HTTP_PORT', '4318')}"))
      end

      def jaeger_endpoint
        get("ZDOTS_JAEGER_ENDPOINT", "http://#{get('ZDOTS_JAEGER_HOST', '127.0.0.1')}:#{get('ZDOTS_JAEGER_UI_PORT', '16686')}")
      end

      def o2_endpoint
        get("ZDOTS_O2_ENDPOINT", "http://#{get('ZDOTS_O2_HOST', '127.0.0.1')}:#{get('ZDOTS_O2_PORT', '5080')}")
      end

      def database_url_default
        get("ZDOTS_DATABASE_URL", "postgresql://zdots_rw@/my")
      end

      private

      def load_defaults
        zdotdir = ENV.fetch("ZDOTDIR", File.expand_path("../..", __dir__))
        path = File.join(zdotdir, "etc", "defaults.env")
        out = {}
        return out unless File.readable?(path)

        File.foreach(path) do |raw|
          line = raw.strip
          next if line.empty? || line.start_with?("#")

          line = line.sub(/\Aexport\s+/, "")
          k, v = line.split("=", 2)
          next unless k && v

          k = k.strip
          v = v.strip
          v = v[1..-2] if v.length >= 2 && ((v[0] == '"' && v[-1] == '"') || (v[0] == "'" && v[-1] == "'"))
          if (m = DEFAULTS_RE.match(v))
            v = ENV[m[1]].to_s.empty? ? m[2] : ENV[m[1]]
          elsif v.include?("$") || v.include?("`")
            next
          end
          out[k] = v unless k.empty?
        end
        out
      end
    end
  end
end
