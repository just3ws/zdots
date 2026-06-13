# frozen_string_literal: true

require "digest"
require "fileutils"
require "yaml"

module Zdots
  # WikiExporter — exports methodologies and lessons from the database to markdown wiki files.
  #
  # Reads Zdots::Models::Methodology and Zdots::Models::Lesson records,
  # writes them to docs/wiki/{methodologies,lessons}/ directories with YAML frontmatter.
  #
  # Structure:
  #   docs/wiki/
  #   ├── INDEX.md                    (generated: tables, tag cloud)
  #   ├── methodologies/<slug>.md
  #   └── lessons/<slug>.md
  #
  # Frontmatter:
  #   ---
  #   type: methodology|lesson
  #   slug: my-slug
  #   title: My Title
  #   tags: [tag1, tag2]
  #   updated_at: 2026-06-12T00:00:00Z  (methodology) or
  #   created_at: 2026-06-12T00:00:00Z  (lesson)
  #   ---
  #
  # Operation is idempotent: safe to run multiple times. Existing files are overwritten.
  class WikiExporter
    def initialize(db, wiki_dir = nil)
      @db = db
      @wiki_dir = wiki_dir || File.join(Zdots::ZDOTDIR, "docs", "wiki")
    end

    # Export all methodologies and lessons to wiki markdown files.
    # Creates directories, writes files, generates index, prints summary.
    def run
      puts "WikiExporter: starting export to #{@wiki_dir}"

      # Create directory structure
      create_directories

      # Export records
      methodologies = export_methodologies
      lessons = export_lessons

      # Generate index
      write_index(methodologies, lessons)

      # Summary
      total = methodologies.count + lessons.count
      puts "WikiExporter: completed — #{methodologies.count} methodologies, " \
           "#{lessons.count} lessons, #{total} total"
    end

    # Export all methodologies from db[:methodologies] to methodologies/<slug>.md.
    # Returns array of exported methodology hashes.
    def export_methodologies
      exported = []

      # Query via model layer to get proper decryption + access control
      Zdots::Models::Methodology.order(:slug).all.each do |model|
        slug = model.slug
        title = model.title
        tags = Array(model.tags || [])
        timestamp = model.updated_at
        content = model.content.to_s

        # Write file
        file_path = File.join(@wiki_dir, "methodologies", "#{slug}.md")
        write_markdown_file(
          file_path,
          type: "methodology",
          slug: slug,
          title: title,
          tags: tags,
          timestamp: timestamp,
          content: content
        )

        exported << { slug: slug, title: title, tags: tags, type: "methodology" }
      end

      exported
    rescue StandardError => e
      puts "  [error] export_methodologies failed: #{e.message}"
      raise
    end

    # Export all lessons from db[:lessons] to lessons/<slug>.md.
    # Returns array of exported lesson hashes.
    def export_lessons
      exported = []

      # Query via model layer to get proper decryption + access control
      Zdots::Models::Lesson.order(:created_at).all.each do |model|
        id = model.id
        context = model.context
        tags = Array(model.tags || [])
        timestamp = model.created_at
        content = model.content.to_s

        # Derive slug from source_trace_id or hash of ID
        slug = if model.source_trace_id && !model.source_trace_id.empty?
                 # Use first 12 chars of trace ID as slug
                 model.source_trace_id[0..11]
               else
                 # Fallback: SHA1 hash of ID (deterministic, stable)
                 Digest::SHA1.hexdigest(id.to_s)[0..11]
               end

        # Write file
        file_path = File.join(@wiki_dir, "lessons", "#{slug}.md")
        title = context || "Lesson #{slug}"

        write_markdown_file(
          file_path,
          type: "lesson",
          slug: slug,
          title: title,
          tags: tags,
          timestamp: timestamp,
          context: context,
          content: content
        )

        exported << { slug: slug, title: title, tags: tags, type: "lesson" }
      end

      exported
    rescue StandardError => e
      puts "  [error] export_lessons failed: #{e.message}"
      raise
    end

    # Write INDEX.md with methodology and lesson tables, tag cloud.
    # Input: exported (array of hashes with slug, title, tags, type).
    def write_index(methodologies, lessons)
      index_path = File.join(@wiki_dir, "INDEX.md")

      content = +"# Wiki Index\n\n"

      # Methodology table
      content << "## Methodologies (#{methodologies.count})\n\n"
      if methodologies.any?
        content << "| Title | Tags |\n"
        content << "|-------|------|\n"
        methodologies.sort_by { |m| m[:title] }.each do |m|
          tags_str = m[:tags].any? ? m[:tags].join(", ") : "—"
          link = "[#{escape_markdown(m[:title])}](methodologies/#{m[:slug]}.md)"
          content << "| #{link} | #{tags_str} |\n"
        end
        content << "\n"
      else
        content << "_(none)_\n\n"
      end

      # Lesson table
      content << "## Lessons (#{lessons.count})\n\n"
      if lessons.any?
        content << "| Context | Tags |\n"
        content << "|---------|------|\n"
        lessons.sort_by { |l| l[:title] }.each do |l|
          tags_str = l[:tags].any? ? l[:tags].join(", ") : "—"
          link = "[#{escape_markdown(l[:title])}](lessons/#{l[:slug]}.md)"
          content << "| #{link} | #{tags_str} |\n"
        end
        content << "\n"
      else
        content << "_(none)_\n\n"
      end

      # Tag cloud
      all_tags = (methodologies + lessons).flat_map { |r| r[:tags] }.uniq.sort
      if all_tags.any?
        content << "## Tags\n\n"
        all_tags.each do |tag|
          count_m = methodologies.count { |m| m[:tags].include?(tag) }
          count_l = lessons.count { |l| l[:tags].include?(tag) }
          total = count_m + count_l
          content << "- **#{tag}** (#{total})\n"
        end
        content << "\n"
      end

      content << "---\n\nGenerated by `Zdots::WikiExporter`\n"

      File.write(index_path, content)
      puts "  [wrote] INDEX.md"
    rescue StandardError => e
      puts "  [error] write_index failed: #{e.message}"
      raise
    end

    private

    # Create wiki directory structure: wiki/, wiki/methodologies/, wiki/lessons/
    def create_directories
      [@wiki_dir, File.join(@wiki_dir, "methodologies"), File.join(@wiki_dir, "lessons")].each do |dir|
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end
    end

    # Write a single markdown file with YAML frontmatter.
    # Params:
    #   - file_path: target .md file
    #   - type: 'methodology' or 'lesson'
    #   - slug: unique slug
    #   - title: display title
    #   - tags: array of tags
    #   - timestamp: Time object (updated_at or created_at)
    #   - content: markdown body
    #   - context: (lesson only) optional context string
    def write_markdown_file(file_path, type:, slug:, title:, tags:, timestamp:, content:, context: nil)
      # Build YAML frontmatter
      fm = {
        "type" => type,
        "slug" => slug,
        "title" => title,
        "tags" => tags.empty? ? [] : tags
      }

      # Add timestamp field
      timestamp_key = type == "lesson" ? "created_at" : "updated_at"
      fm[timestamp_key] = timestamp.iso8601

      # Add context for lessons
      fm["context"] = context if context

      # YAML serialization with escaped quotes
      yaml_str = YAML.dump(fm, permitted_classes: [Array])
      # Remove leading "---\n" (YAML adds it) and trailing newline
      yaml_content = yaml_str.sub(/^---\n/, "").chomp

      # Assemble file
      file_content = "---\n#{yaml_content}\n---\n\n#{content.strip}\n"

      File.write(file_path, file_content)
    end

    # Escape special markdown characters in text.
    def escape_markdown(text)
      chars = ["\\", "`", "*", "_", "{", "}", "(", ")", "+", "#", "-", "!", ".", "|", "[", "]"]
      result = text.to_s
      chars.each { |char| result = result.gsub(char, "\\#{char}") }
      result
    end
  end
end
