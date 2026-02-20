require "../config"
require "../vultr/client"
require "../vultr/status_map"
require "../util/env"

# RemoveAllInstances command implementation.
# Removes all instances tagged with the current GARM_CONTROLLER_ID.

module GarmProviderVultr
  module Commands
    def self.remove_all_instances
      controller_id = Env.controller_id
      config_file = Env.config_file
      extra_specs = Env.pool_extra_specs

      STDERR.puts "[remove_all] removing all instances for controller=#{controller_id}"

      config = ProviderConfig.load(config_file)
      resolved = ResolvedConfig.new(config, extra_specs)
      client = Vultr::Client.new(resolved.api_key)

      # List all instances tagged with this controller
      tag = "#{CONTROLLER_TAG_PREFIX}#{controller_id}"
      vultr_instances = client.list_instances(tag: tag)

      STDERR.puts "[remove_all] found #{vultr_instances.size} instances to remove"

      errors = [] of String
      vultr_instances.each do |vi|
        begin
          client.delete_instance(vi.id)
          STDERR.puts "[remove_all] deleted instance id=#{vi.id} name=#{vi.label}"
        rescue ex
          errors << "failed to delete instance #{vi.id}: #{ex.message}"
          STDERR.puts "[remove_all] #{errors.last}"
        end
      end

      unless errors.empty?
        raise "failed to remove some instances: #{errors.join("; ")}"
      end

      STDERR.puts "[remove_all] all instances removed"
    end
  end
end
