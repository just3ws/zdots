# frozen_string_literal: true

require "yaml"
require "json"
require "pathname"
require "fileutils"

module Zdots
  # Deep merge utility (Hash extension)
  module HashExtensions
    def deep_merge(other)
      merge(other) do |_key, this_val, other_val|
        if this_val.is_a?(Hash) && other_val.is_a?(Hash)
          this_val.deep_merge(other_val)
        else
          other_val
        end
      end
    end
  end

  class Config
    DEFAULT_CONFIG_PATH = Pathname.new("~/.zdots/config.yaml").expand_path
    DEFAULT_LOCAL_CONFIG_PATH = Pathname.new("~/.zdots/config.local.yaml").expand_path
    DEFAULT_SCHEMA_VERSION_PATH = Pathname.new("~/.zdots/schema-version.yaml").expand_path
    DEFAULTS_PATH = Pathname.new(__dir__).parent.parent / "etc" / "config.default.yaml"

    attr_reader :config, :profile

    def initialize(profile: nil, config_path: nil, local_config_path: nil, schema_path: nil)
      @config_path = Pathname.new(config_path || DEFAULT_CONFIG_PATH)
      @local_config_path = Pathname.new(local_config_path || DEFAULT_LOCAL_CONFIG_PATH)
      @schema_version_path = Pathname.new(schema_path || DEFAULT_SCHEMA_VERSION_PATH)
      @profile = profile || ENV.fetch("ZDOTS_PROFILE", "default")
      @config = {}

      load_config
    end

    # Load configuration from defaults + config file + local overrides + active profile
    def load_config
      defaults = load_defaults
      config_file = load_yaml(@config_path) || {}
      local_config = load_yaml(@local_config_path) || {}

      # Merge in order: defaults → config → local
      @config = deep_merge(defaults, config_file)
      @config = deep_merge(@config, local_config)

      # Apply profile overrides if not default
      apply_profile_overrides if @profile != "default" && @config.dig("profiles", @profile)

      # Expand environment variables and Keychain substitutions
      expand_variables!

      @config
    end

    # Get a setting by dot-notation path (e.g., "ai.mode" → config["ai"]["mode"])
    def get(key_path)
      keys = key_path.to_s.split(".")
      keys.reduce(@config) { |obj, k| obj.is_a?(Hash) ? obj[k] : nil }
    end

    # Set a setting by dot-notation path
    def set(key_path, value)
      keys = key_path.to_s.split(".")
      key = keys.pop

      target = @config
      keys.each do |k|
        target[k] ||= {}
        target = target[k]
      end

      target[key] = value
    end

    # Save current configuration to file
    def save!(target_path = @config_path)
      target_path = Pathname.new(target_path)
      FileUtils.mkdir_p(target_path.parent) unless target_path.parent.exist?

      File.write(target_path, YAML.dump(@config))
    end

    # Validate configuration against schema
    def validate!(schema_path = nil)
      schema_path ||= DEFAULTS_PATH.parent / "config-schema.json"
      return true unless schema_path.exist?

      schema = JSON.parse(File.read(schema_path))

      # Basic validation: check required keys
      required = schema.dig("required") || []
      missing = required.reject { |k| @config.key?(k) }

      raise "Missing required config keys: #{missing.join(', ')}" unless missing.empty?

      # Validate ai.mode enum
      ai_mode = get("ai.mode")
      valid_modes = %w[local cloud none]
      raise "Invalid ai.mode: #{ai_mode}. Must be one of: #{valid_modes.join(', ')}" if ai_mode && !valid_modes.include?(ai_mode)

      true
    end

    # List all settings with values
    def list(as_json: false)
      if as_json
        JSON.pretty_generate(@config)
      else
        flatten_hash(@config).sort.map { |k, v| "#{k}=#{v}" }.join("\n")
      end
    end

    # Export current state as YAML
    def export
      YAML.dump(@config)
    end

    # Reset a single key to default, or reset all to defaults
    def reset!(key_path = nil)
      if key_path.nil?
        @config = load_defaults
      else
        defaults = load_defaults
        value = defaults.dig(*key_path.to_s.split("."))
        set(key_path, value) if value
      end
    end

    # Check if a key exists
    def key?(key_path)
      keys = key_path.to_s.split(".")
      value = keys.reduce(@config) { |obj, k| obj.is_a?(Hash) && obj.key?(k) ? obj[k] : nil }
      !value.nil?
    end

    private

    def load_defaults
      return {} unless DEFAULTS_PATH.exist?

      load_yaml(DEFAULTS_PATH) || {}
    end

    def load_yaml(path)
      return nil unless path.exist?

      YAML.safe_load(File.read(path), permitted_classes: [Symbol], symbolize_names: false)
    rescue YAML::ParseError => e
      raise "Invalid YAML in #{path}: #{e.message}"
    end

    def apply_profile_overrides
      profile_config = @config.dig("profiles", @profile) || {}
      @config = deep_merge(@config, profile_config)
    end

    def deep_merge(base, overrides)
      return base if overrides.nil? || !overrides.is_a?(Hash)

      base.merge(overrides) do |_key, base_val, override_val|
        if base_val.is_a?(Hash) && override_val.is_a?(Hash)
          deep_merge(base_val, override_val)
        else
          override_val
        end
      end
    end

    def expand_variables!
      @config = expand_hash(@config)
    end

    def expand_hash(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), acc|
          acc[k] = expand_hash(v)
        end
      when String
        expand_string(obj)
      when Array
        obj.map { |item| expand_hash(item) }
      else
        obj
      end
    end

    def expand_string(str)
      str.gsub(/\$\{([A-Z_][A-Z0-9_]*)\}/) do |match|
        var_name = Regexp.last_match(1)
        # Try environment variable first, then Keychain (if available)
        ENV[var_name] || fetch_from_keychain(var_name) || match
      end
    end

    def fetch_from_keychain(var_name)
      # Try to fetch from macOS Keychain
      # `security find-generic-password -s zdots -a VARNAME -w`
      return nil unless system("which security", out: File::NULL, err: File::NULL)

      output = `security find-generic-password -s zdots -a #{var_name} -w 2>/dev/null`.strip
      output.empty? ? nil : output
    rescue StandardError
      nil
    end

    def flatten_hash(hash, parent_key = "")
      hash.each_with_object({}) do |(k, v), acc|
        new_key = parent_key.empty? ? k.to_s : "#{parent_key}.#{k}"
        if v.is_a?(Hash)
          acc.merge!(flatten_hash(v, new_key))
        else
          acc[new_key] = v
        end
      end
    end
  end
end
