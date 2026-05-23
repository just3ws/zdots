# frozen_string_literal: true





require "logger"

require_relative "zdots/db"
require_relative "zdots/crypto/key_store"
require_relative "zdots/models/encrypted_content"
require_relative "zdots/ai/client"

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
