# frozen_string_literal: true

require "open3"

module Zdots
  class BoundedTimeout < StandardError; end

  # Seconds to let a child honor TERM before escalating to an uncatchable KILL.
  KILL_GRACE = 3

  # Run a subprocess with a hard wall-clock ceiling. A present-but-hung binary
  # (on PATH but wedged — dead network, stuck ffmpeg/whisper) would otherwise
  # block the caller forever, and `rescue StandardError` can't catch a hang —
  # only an exception. On timeout we:
  #   - kill the child's whole process GROUP, not just its pid: the media
  #     recipes fork yt-dlp/whisper/ffmpeg, and TERM to the wrapper alone leaves
  #     those grandchildren running detached. pgroup: true makes the child a new
  #     group leader (pgid == its pid), so the negative-pid signals below hit
  #     ONLY its group, never the worker's own.
  #   - escalate TERM → KILL: a process wedged in a syscall (precisely the hang
  #     we target) is the one least likely to honor TERM, and then a plain
  #     wait_thr.join would re-hang. KILL is uncatchable, so the reap completes.
  # Then we raise BoundedTimeout so the caller's normal rescue path runs.
  #
  # A reader thread drains output concurrently, so a child that fills the pipe
  # buffer before exiting can't deadlock us regardless of output size.
  #
  # merge_err: true folds stderr into the returned string (popen2e) — for
  # callers that used capture2e and raise with the combined output on failure.
  # stdin_data: written then EOF'd; omit for children that don't read stdin.
  #
  # Returns [output_string, Process::Status]. Raises BoundedTimeout on timeout.
  def self.run_bounded(*cmd, timeout:, stdin_data: nil, merge_err: false)
    opener = merge_err ? Open3.method(:popen2e) : Open3.method(:popen2)
    opener.call(*cmd, pgroup: true) do |stdin, out, wait_thr|
      reader = Thread.new { out.read }
      begin
        stdin.write(stdin_data) if stdin_data
      rescue Errno::EPIPE
        # child exited before reading stdin; its status/output tell the story
      end
      stdin.close

      if wait_thr.join(timeout).nil?
        kill_group("TERM", wait_thr.pid)
        unless wait_thr.join(KILL_GRACE)
          kill_group("KILL", wait_thr.pid) # uncatchable — child + group die now
          wait_thr.join                    # reap
        end
        reader.kill
        raise BoundedTimeout, "timed out after #{timeout}s: #{cmd.first}"
      end
      [reader.value, wait_thr.value]
    end
  end

  # Signal the child's whole process group (negative pid). ESRCH = the group
  # already exited between our join timing out and the signal — nothing to kill.
  def self.kill_group(signal, pid)
    Process.kill(signal, -pid)
  rescue Errno::ESRCH
    # raced: group already gone
  end
end
