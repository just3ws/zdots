# frozen_string_literal: true

require_relative "../../zdots"
require_relative "job"

job = Zdots::Models::Job.first
if job
  puts "Job ID: #{job.id} (class: #{job.id.class})"
  puts "Job Status: #{job.status}"
else
  puts "No jobs found."
end
