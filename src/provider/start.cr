require "../config"
require "../vultr/client"
require "../util/env"

# Start command implementation.
# Starts (boots) the instance identified by GARM_INSTANCE_ID.

module GarmProviderVultr
  module Commands
    def self.start_instance
      instance_id = Env.instance_id
      config_file = Env.config_file
      extra_specs = Env.pool_extra_specs

      raise "GARM_INSTANCE_ID is required for Start" if instance_id.empty?

      STDERR.puts "[start] starting instance id=#{instance_id}"

      config = ProviderConfig.load(config_file)
      resolved = ResolvedConfig.new(config, extra_specs)
      client = Vultr::Client.new(resolved.api_key)

      client.start_instance(instance_id)

      STDERR.puts "[start] instance #{instance_id} started"
    end
  end
end
