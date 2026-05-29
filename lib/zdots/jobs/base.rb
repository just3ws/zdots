# frozen_string_literal: true

require "opentelemetry"

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

        # Link to the trace_id stored in the job if available
        # (Though claim_next_job updates it to the worker's current trace)

        tracer.in_span("job.perform", attributes: {
                         "job.id" => job.id.to_s,
                         "job.type" => job.type
                       }) do |span|
          result = run
          job.complete!
          result
        rescue StandardError => e
          span.record_exception(e)
          span.status = OpenTelemetry::Trace::Status.error(e.message)
          job.fail!(e.message)
          raise e
        end
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
