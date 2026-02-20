require "../config"
require "../vultr/client"
require "../util/env"

# Stop command implementation.
# Halts (stops) the instance identified by GARM_INSTANCE_ID.

module GarmProviderVultr
  module Commands
    def self.stop_instance
      instance_id = Env.instance_id
      config_file = Env.config_file
      extra_specs = Env.pool_extra_specs

      raise "GARM_INSTANCE_ID is required for Stop" if instance_id.empty?

      STDERR.puts "[stop] stopping instance id=#{instance_id}"

      config = ProviderConfig.load(config_file)
      resolved = ResolvedConfig.new(config, extra_specs)
      client = Vultr::Client.new(resolved.api_key)

      client.halt_instance(instance_id)

      STDERR.puts "[stop] instance #{instance_id} stopped"
    end
  end
end
