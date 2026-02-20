require "base64"
require "json"

# Helpers for reading garm environment variables.

module GarmProviderVultr
  module Env
    # Read a required environment variable
    def self.require(name : String) : String
      value = ENV[name]?
      raise "required environment variable #{name} is not set" if value.nil? || value.empty?
      value
    end

    # Read an optional environment variable
    def self.get(name : String, default : String = "") : String
      ENV[name]? || default
    end

    def self.command : String
      self.require("GARM_COMMAND")
    end

    def self.controller_id : String
      self.require("GARM_CONTROLLER_ID")
    end

    def self.config_file : String
      self.require("GARM_PROVIDER_CONFIG_FILE")
    end

    def self.pool_id : String
      self.get("GARM_POOL_ID")
    end

    def self.instance_id : String
      self.get("GARM_INSTANCE_ID")
    end

    def self.interface_version : String
      self.get("GARM_INTERFACE_VERSION")
    end

    # Decode and parse the base64-encoded pool extra specs
    def self.pool_extra_specs : ExtraSpecs?
      raw = self.get("GARM_POOL_EXTRASPECS")
      return nil if raw.empty?

      decoded = Base64.decode_string(raw)
      return nil if decoded.empty? || decoded == "null"

      ExtraSpecs.from_json(decoded)
    rescue ex : Base64::Error
      STDERR.puts "[env] failed to decode GARM_POOL_EXTRASPECS: #{ex.message}"
      nil
    rescue ex : JSON::ParseException
      STDERR.puts "[env] failed to parse GARM_POOL_EXTRASPECS: #{ex.message}"
      nil
    end
  end
end
