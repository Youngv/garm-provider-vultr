require "../config"
require "../vultr/client"
require "../vultr/status_map"
require "../util/env"

# ListInstances command implementation.
# Returns JSON array of ProviderInstance for all instances in the given pool.

module GarmProviderVultr
  module Commands
    def self.list_instances
      pool_id = Env.pool_id
      controller_id = Env.controller_id
      config_file = Env.config_file
      extra_specs = Env.pool_extra_specs

      STDERR.puts "[list] listing instances for pool=#{pool_id} controller=#{controller_id}"

      config = ProviderConfig.load(config_file)
      resolved = ResolvedConfig.new(config, extra_specs)
      client = Vultr::Client.new(resolved.api_key)

      # List all instances tagged with this pool
      tag = "#{POOL_TAG_PREFIX}#{pool_id}"
      vultr_instances = client.list_instances(tag: tag)

      # Filter to ensure they also belong to this controller
      filtered = vultr_instances.select do |vi|
        GarmProviderVultr.belongs_to_controller?(vi.tags, controller_id)
      end

      result = filtered.map do |vi|
        GarmProviderVultr.vultr_to_garm_instance(vi)
      end

      STDERR.puts "[list] found #{result.size} instances"
      puts result.to_json
    end
  end
end
