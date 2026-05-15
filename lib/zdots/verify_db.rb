# frozen_string_literal: true

require_relative "../zdots"

begin
  Zdots.init_otel("zdots-verify")
  db = Zdots.db
  puts "Connected to database: #{db.opts[:database] || db.uri}"
  
  # Check if jobs table exists
  if db.table_exists?(:jobs)
    count = db[:jobs].count
    puts "Jobs table found. Record count: #{count}"
  else
    puts "Jobs table NOT found!"
    exit 1
  end

  puts "Sequel integration verified successfully."
rescue => e
  puts "Verification failed: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
