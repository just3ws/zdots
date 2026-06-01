# frozen_string_literal: true

require "pathname"

module RubyAudit
  # Detects Ruby/Rails/framework versions from a target directory.
  # Reads Gemfile.lock (authoritative), falls back to .ruby-version and Gemfile.
  class Detector
    attr_reader :root

    def initialize(root)
      @root = Pathname.new(root).expand_path
    end

    def ruby_version
      @ruby_version ||= from_ruby_version_file || from_gemfile_lock_ruby || from_gemfile_ruby || "unknown"
    end

    def rails_version
      @rails_version ||= gem_version("rails") || gem_version("railties")
    end

    def framework
      return :rails  if rails_version
      return :sinatra if gem_version("sinatra")
      return :hanami  if gem_version("hanami")
      :ruby
    end

    def database
      return :postgresql if gem_version("pg")
      return :mariadb    if gem_version("mariadb")
      return :mysql      if gem_version("mysql2") || gem_version("mysql")
      return :sqlite     if gem_version("sqlite3")
      return :mongodb    if gem_version("mongoid") || gem_version("mongo")
      nil
    end

    def infrastructure
      infra = []
      infra << :docker if (root / "Dockerfile").exist? || (root / "docker-compose.yml").exist? || (root / "docker-compose.yaml").exist?
      infra << :k8s    if (root / "k8s").exist? || (root / "kubernetes").exist? || Dir.glob((root / "**/*.yaml").to_s).any? { |f| File.read(f).include?("apiVersion: v1") rescue false }
      infra
    end

    def gem_version(name)
      return nil unless lockfile_gems

      lockfile_gems[name]
    end

    def ruby_minor
      ruby_version.then { |v| v.match?(/\A\d+\.\d+/) ? v[/\A\d+\.\d+/] : nil }
    end

    def rails_major_minor
      rails_version&.then { |v| v[/\A\d+\.\d+/] }
    end

    def summary
      {
        ruby:       ruby_version,
        rails:      rails_version,
        framework:  framework.to_s,
        database:   database.to_s,
        infrastructure: infrastructure.join(", "),
        gemfile:    (root / "Gemfile").exist?,
        gemfile_lock: (root / "Gemfile.lock").exist?,
        schema:     (root / "db" / "schema.rb").exist? || (root / "db" / "structure.sql").exist?
      }
    end

    private

    def from_ruby_version_file
      f = root / ".ruby-version"
      f.exist? ? f.read.strip.delete_prefix("ruby-") : nil
    end

    def from_gemfile_lock_ruby
      f = root / "Gemfile.lock"
      return nil unless f.exist?

      f.each_line do |line|
        return Regexp.last_match(1).strip if line =~ /\ARUBY VERSION\z/ || line =~ /\s+ruby (\S+)/
      end
      nil
    end

    def from_gemfile_ruby
      f = root / "Gemfile"
      return nil unless f.exist?

      f.each_line do |line|
        return Regexp.last_match(1) if line =~ /^ruby\s+['"]([\d.]+)['"]/
      end
      nil
    end

    def lockfile_gems
      @lockfile_gems ||= begin
        f = root / "Gemfile.lock"
        return nil unless f.exist?

        gems = {}
        in_specs = false
        f.each_line do |line|
          in_specs = true  if line.strip == "GEM" || line.strip == "specs:"
          in_specs = false if in_specs && line =~ /\A[A-Z]/ && line.strip != "specs:"
          next unless in_specs

          if line =~ /^\s{4}(\S+)\s+\(([\d.]+)\)/
            gems[Regexp.last_match(1)] = Regexp.last_match(2)
          end
        end
        gems
      end
    end
  end
end
