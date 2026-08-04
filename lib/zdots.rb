# frozen_string_literal: true

require "logger"

require_relative "zdots/db"
require_relative "zdots/crypto/key_store"
require_relative "zdots/models/encrypted_content"
require_relative "zdots/models/searchable"
require_relative "zdots/ai/client"

module Zdots
  ZDOTDIR = ENV.fetch("ZDOTDIR", File.expand_path("..", __dir__))

  class << self
    def init_otel(service_name = "zdots-brain")
      # Lazy: callers require only the opentelemetry API; the SDK + exporter
      # load here so non-telemetry CLI paths don't pay the startup cost.
      require "opentelemetry-sdk"
      require "opentelemetry-exporter-otlp"
      # c.use_all only installs instrumentations already registered in
      # OpenTelemetry::Instrumentation.registry — without this require, the
      # registry is empty and use_all silently no-ops (confirmed 2026-08-03:
      # zdots-worker processed 311 jobs/30d with zero spans reaching
      # OpenObserve; this was the actual cause, not a missing OTEL_* env var).
      require "opentelemetry/instrumentation/all"

      # Silence OTel diagnostic logging unless debug mode is active
      OpenTelemetry.logger = Logger.new(nil) unless ENV["ZDOTS_DEBUG"] == "1"

      OpenTelemetry::SDK.configure do |c|
        c.service_name = service_name
        c.use_all
      end
    end

    def db
      Zdots::DB.connect
    end
  end
end
