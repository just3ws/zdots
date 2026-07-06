# frozen_string_literal: true

# Runnable check for Zdots.run_bounded (the "Claude inaccessible" guard).
# Plain ruby, no framework/DB:  ruby spec/bounded_run_test.rb
require_relative "../lib/zdots/bounded_run"

# 1. A hung process (claude present, service unreachable) times out promptly,
#    raises BoundedTimeout, and is reaped (no lingering child).
before = `pgrep -f 'sleep 47' 2>/dev/null`.split.size
t0 = Time.now
raised = false
begin
  Zdots.run_bounded("sleep", "47", stdin_data: "", timeout: 1)
rescue Zdots::BoundedTimeout
  raised = true
end
elapsed = Time.now - t0
sleep 0.3 # let the reap settle
after = `pgrep -f 'sleep 47' 2>/dev/null`.split.size

raise "did not raise BoundedTimeout on hang" unless raised
raise "timeout too slow: #{elapsed}s" unless elapsed < 3
raise "child not reaped: #{before} -> #{after}" unless after <= before

# 2. A fast process returns its stdout and a success status.
out, status = Zdots.run_bounded("printf", "hi", stdin_data: "", timeout: 5)
raise "wrong stdout: #{out.inspect}" unless out == "hi"
raise "not success" unless status.success?

# 3. stdin is delivered to the child.
out, = Zdots.run_bounded("cat", stdin_data: "piped", timeout: 5)
raise "stdin not delivered: #{out.inspect}" unless out == "piped"

puts "bounded_run: OK"
