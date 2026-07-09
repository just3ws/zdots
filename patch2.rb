content = File.read("lib/zdots/jobs/transcribe_chunk.rb")
content.gsub!(/rescue StandardError => e\n\s*pr&\.update\(status: "failed"[^\n]+\n\s*raise e/) do |match|
  <<~REPLACE.chomp
rescue Sequel::NoExistingObject => e
        warn "pipeline_run was deleted, assuming restart/cancel"
        raise e
      rescue StandardError => e
        pr&.update(status: "failed", error_message: e.message, finished_at: Sequel::CURRENT_TIMESTAMP) rescue nil if defined?(pr)
        raise e
  REPLACE
end
File.write("lib/zdots/jobs/transcribe_chunk.rb", content)
