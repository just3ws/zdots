# frozen_string_literal: true

# Runnable check for Zdots.run_bounded (the "Claude/recipe inaccessible" guard).
# Plain ruby, no framework/DB:  ruby spec/bounded_run_test.rb
require_relative "../lib/zdots/bounded_run"

def assert(cond, msg) = (raise msg unless cond)

# Unique sleep durations per case so pgrep can't cross-match between tests.

# 1. A hung process times out promptly, raises BoundedTimeout, is reaped.
t0 = Time.now
raised = false
begin
  Zdots.run_bounded("sleep", "471", timeout: 1)
rescue Zdots::BoundedTimeout
  raised = true
end
elapsed = Time.now - t0
sleep 0.3
assert raised, "did not raise BoundedTimeout on hang"
assert elapsed < 3, "timeout too slow: #{elapsed}s"
assert `pgrep -f 'sleep 471' 2>/dev/null`.strip.empty?, "child not reaped"

# 2. GROUP kill: a recipe wrapper forks a grandchild (yt-dlp/whisper stand-in).
#    TERM to the wrapper pid alone would orphan it; the group kill must not.
#    This FAILS with a naive single-pid kill and PASSES with -pid.
begin
  Zdots.run_bounded("sh", "-c", "sleep 619 & wait", timeout: 1, merge_err: true)
rescue Zdots::BoundedTimeout
  # expected
end
sleep 0.3
leaked = `pgrep -f 'sleep 619' 2>/dev/null`.strip
assert leaked.empty?, "grandchild leaked after group-kill: #{leaked}"

# 3. KILL backstop: a child that ignores TERM (a wedged syscall would) must
#    still die, and the escalation must stay bounded (timeout + grace, not ∞).
t1 = Time.now
begin
  Zdots.run_bounded(
    "sh", "-c", 'trap "" TERM; while :; do sleep 0.5; done # zdots_term_ignorer',
    timeout: 1, merge_err: true
  )
rescue Zdots::BoundedTimeout
  # expected
end
esc = Time.now - t1
sleep 0.3
alive = `pgrep -f 'zdots_term_ignorer' 2>/dev/null`.strip
assert alive.empty?, "TERM-ignorer survived — KILL backstop failed: #{alive}"
assert esc < Zdots::KILL_GRACE + 4, "escalation too slow: #{esc}s"

# 4. Fast process returns stdout + success status.
out, status = Zdots.run_bounded("printf", "hi", timeout: 5)
assert out == "hi", "wrong stdout: #{out.inspect}"
assert status.success?, "not success"

# 5. stdin is delivered.
out, = Zdots.run_bounded("cat", stdin_data: "piped", timeout: 5)
assert out == "piped", "stdin not delivered: #{out.inspect}"

# 6. merge_err folds stderr into the returned string (capture2e parity).
out, = Zdots.run_bounded("sh", "-c", "echo to_out; echo to_err >&2", timeout: 5, merge_err: true)
assert out.include?("to_out"), "merge_err lost stdout: #{out.inspect}"
assert out.include?("to_err"), "merge_err lost stderr: #{out.inspect}"

puts "bounded_run: OK"
