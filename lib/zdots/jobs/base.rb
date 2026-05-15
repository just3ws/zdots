# frozen_string_literal: true

require "opentelemetry"

module Zdots
  module Jobs
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
          begin
            result = run
            job.complete!
            result
          rescue => e
            span.record_exception(e)
            span.status = OpenTelemetry::Trace::Status.error(e.message)
            job.fail!(e.message)
            raise e
          end
        end
      end

      def run
        raise NotImplementedError, "#{self.class} must implement #run"
      end

      def payload
        job.payload
      end
    end
  end
end
