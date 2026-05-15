# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry-exporter-otlp"
require "opentelemetry-instrumentation-all"

require "logger"

require_relative "zdots/db"

module Zdots
  ZDOTDIR = ENV.fetch("ZDOTDIR", File.expand_path("..", __dir__))

  class << self
    def init_otel(service_name = "zdots-brain")
      # Silence OTel diagnostic logging unless debug mode is active
      unless ENV["ZDOTS_DEBUG"] == "1"
        OpenTelemetry.logger = Logger.new(nil)
      end

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
