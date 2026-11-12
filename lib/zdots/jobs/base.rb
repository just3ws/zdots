# frozen_string_literal: true

require "opentelemetry"
require_relative "../pipeline_events"

module Zdots
  module Jobs
    @registry = {}

    def self.register(type, klass)
      @registry[type.to_s] = klass
    end

    # Returns the job class for a given type string.
    # Raises ArgumentError if the type is unknown — fail loudly, never silently drop a job.
    def self.for(type)
      @registry.fetch(type.to_s) do
        raise ArgumentError, "unknown job type: #{type.inspect} (registered: #{@registry.keys.sort.join(', ')})"
      end
    end

    class Base
      attr_reader :job

      def initialize(job)
        @job = job
      end

      def self.perform(job)
        new(job).perform_with_otel
      end

      def perform_with_otel
        tracer = OpenTelemetry.tracer_provider.tracer("zdots-jobs")
        parent_ctx = extract_parent_trace_context

        with_optional_context(parent_ctx) do
          tracer.in_span("job.perform", attributes: {
                           "job.id" => job.id.to_s,
                           "job.type" => job.type,
                           "pv.run_id" => job.payload.to_h["panoramic_run_id"]
                         }.compact) do |span|
            Zdots::PipelineEvents.emit(:started, job)
            result = run
            job.complete!(result)
            Zdots::PipelineEvents.emit(:succeeded, job)
            result
          rescue StandardError => e
            span.record_exception(e)
            span.status = OpenTelemetry::Trace::Status.error(e.message)
            job.fail!(e.message)
            Zdots::PipelineEvents.emit(:failed, job, error: e)
            raise e
          end
        end
      end

      def extract_parent_trace_context
        pl = job.payload.to_h
        tp = pl["traceparent"].to_s
        if tp.empty? && pl["trace_id"].to_s.match?(/\A[0-9a-f]{32}\z/i)
          psid = pl["parent_span_id"].to_s.match?(/\A[0-9a-f]{16}\z/i) ? pl["parent_span_id"] : "0000000000000001"
          tp = "00-#{pl['trace_id'].downcase}-#{psid.downcase}-01"
        end
        return nil unless tp.match?(/\A00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}\z/i)

        OpenTelemetry.propagation.extract({ "traceparent" => tp.downcase })
      rescue StandardError
        nil
      end

      def with_optional_context(ctx)
        return yield unless ctx

        OpenTelemetry::Context.with_current(ctx) { yield }
      end

      def run
        raise NotImplementedError, "#{self.class} must implement #run"
      end

      def payload
        job.payload
      end

      private

      # Loads a job prompt template from etc/prompts/jobs/<name>.txt and
      # interpolates {{key}} placeholders with the provided vars.
      def load_prompt(name, **vars)
        path = File.join(Zdots::ZDOTDIR, "etc", "prompts", "jobs", "#{name}.txt")
        raise "prompt not found: #{path}" unless File.exist?(path)

        vars.reduce(File.read(path)) { |t, (k, v)| t.gsub("{{#{k}}}", v.to_s) }
      end
    end
  end
end
