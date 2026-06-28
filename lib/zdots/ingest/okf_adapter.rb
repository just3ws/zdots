# frozen_string_literal: true
require "digest"
require "yaml"
require "time"

module Zdots
  module Ingest
    class OkfAdapter
      RESERVED = %w[index.md log.md].freeze

      def initialize(bundle_path, dry_run: false)
        @bundle = File.expand_path(bundle_path)
        @dry_run = dry_run
      end

      def ingest
        results = { ingested: 0, skipped: 0, unknown_types: [] }

        Dir.glob(File.join(@bundle, "**", "*.md")).sort.each do |file|
          next if RESERVED.include?(File.basename(file))

          raw  = File.read(file)
          fm, body = parse_frontmatter(raw)

          unless fm
            puts "  [skip] no frontmatter: #{File.basename(file)}"
            results[:skipped] += 1
            next
          end

          # OKF required field; harness-managed bundles nest under metadata.*
          type_str = fm["type"] || fm.dig("metadata", "type")
          if type_str.nil? || type_str.to_s.empty?
            puts "  [skip] missing type: #{File.basename(file)}"
            results[:skipped] += 1
            next
          end

          title  = fm["title"] || fm.dig("metadata", "title")
          tags   = Array(fm["tags"] || fm.dig("metadata", "tags"))
          ts_raw = fm["timestamp"] || fm.dig("metadata", "timestamp")
          fetched_at = ts_raw ? Time.parse(ts_raw.to_s) : nil

          if @dry_run
            puts "  [dry-run] #{type_str} '#{title || File.basename(file)}' (#{tags.length} tags)"
            results[:ingested] += 1
            next
          end

          doc = Models::SourceDocument.upsert_by_uri(
            uri:         "file://#{file}",
            source_type: "okf",
            title:       title,
            body_md:     body.strip,
            checksum:    Digest::SHA256.hexdigest(raw),
            provenance:  { "file" => file, "okf_type" => type_str.to_s, "bundle" => @bundle },
            fetched_at:  fetched_at
          )

          # Type-bridge: OKF type + tags → concept slugs via concept_alias
          ([type_str.to_s] + tags).each do |word|
            concept = Models::Concept.resolve(word)
            if concept
              Zdots.db[:concept_tag]
                   .insert_conflict(target: %i[concept_id target_kind target_id])
                   .insert(concept_id: concept.id, target_kind: "source_document", target_id: doc.id)
            else
              unless results[:unknown_types].include?(word)
                results[:unknown_types] << word
                system("logger", "-t", "zdots-okf", "unknown-type: #{word} (#{file})")
              end
            end
          end

          puts "  [ok] #{File.basename(file)}"
          results[:ingested] += 1
        end

        results
      end

      private

      def parse_frontmatter(raw)
        return [nil, raw] unless raw.start_with?("---\n")
        close = raw.index("\n---\n", 4)
        return [nil, raw] if close.nil?
        fm = YAML.safe_load(raw[4...close], permitted_classes: [Symbol, Date, Time])
        [fm, raw[(close + 5)..]]
      rescue StandardError
        [nil, raw]
      end
    end
  end
end
