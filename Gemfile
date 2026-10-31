# frozen_string_literal: true

source "https://rubygems.org"

ruby "~> 4.0"

gem "dotenv"
gem "dry-monads"
gem "opentelemetry-exporter-otlp"
# zdots uses PostgreSQL, RubyLLM/Faraday, and Net::HTTP for embedding calls.
gem "opentelemetry-instrumentation-faraday"
gem "opentelemetry-instrumentation-net_http"
gem "opentelemetry-instrumentation-pg"
gem "opentelemetry-sdk"
gem "pg"
gem "ruby_llm"
gem "sequel"

group :test do
  gem "bundler-audit", require: false
  gem "rspec"
  gem "rubocop", require: false
  gem "simplecov", require: false
end

# Audit gems are in etc/ruby-audit/Gemfile — run: ruby-audit --setup
