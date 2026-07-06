# frozen_string_literal: true

require "open3"

module Zdots
  class BoundedTimeout < StandardError; end

  # Run a subprocess with a hard wall-clock ceiling. A present-but-hung binary
  # (on PATH, but its backing service is unreachable) would otherwise block a
  # caller forever, and `rescue StandardError` can't catch a hang — only an
  # exception. On timeout we TERM the child, reap it (no zombie), and raise
  # BoundedTimeout so the caller's normal rescue path runs.
  #
  # A reader thread drains stdout concurrently, so a child that fills the pipe
  # buffer before exiting can't deadlock us regardless of output size.
  #
  # Returns [stdout_string, Process::Status]. Raises BoundedTimeout on timeout.
  def self.run_bounded(*cmd, stdin_data:, timeout:)
    Open3.popen2(*cmd) do |stdin, stdout, wait_thr|
      reader = Thread.new { stdout.read }
      stdin.write(stdin_data)
      stdin.close
      if wait_thr.join(timeout).nil?
        begin
          Process.kill("TERM", wait_thr.pid)
        rescue Errno::ESRCH
          # raced: child already exited between the join timeout and the kill
        end
        wait_thr.join # reap
        reader.kill
        raise BoundedTimeout, "timed out after #{timeout}s: #{cmd.first}"
      end
      [reader.value, wait_thr.value]
    end
  end
end
