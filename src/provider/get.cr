require "../config"
require "../vultr/client"
require "../vultr/status_map"
require "../util/env"

# GetInstance command implementation.
# Returns ProviderInstance JSON for the instance identified by GARM_INSTANCE_ID.

module GarmProviderVultr
  module Commands
    def self.get_instance
      instance_id = Env.instance_id
      config_file = Env.config_file
      extra_specs = Env.pool_extra_specs

      raise "GARM_INSTANCE_ID is required for GetInstance" if instance_id.empty?

      STDERR.puts "[get] getting instance id=#{instance_id}"

      config = ProviderConfig.load(config_file)
      resolved = ResolvedConfig.new(config, extra_specs)
      client = Vultr::Client.new(resolved.api_key)

      vultr_instance = begin
        client.get_instance(instance_id)
      rescue ex : Vultr::ApiError
        if ex.not_found?
          # Try finding by name
          controller_id = Env.controller_id
          all = client.list_instances(tag: "#{CONTROLLER_TAG_PREFIX}#{controller_id}")
          found = all.find { |i| i.label == instance_id || i.hostname == instance_id }
          raise "instance #{instance_id} not found" unless found
          found
        else
          raise ex
        end
      end

      result = GarmProviderVultr.vultr_to_garm_instance(vultr_instance)
      puts result.to_json
    end
  end
end
