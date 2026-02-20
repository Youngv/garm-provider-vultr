require "../config"
require "../vultr/client"
require "../util/env"

# DeleteInstance command implementation.
# Deletes the Vultr instance identified by GARM_INSTANCE_ID.
# If the instance does not exist, this is a no-op (idempotent).

module GarmProviderVultr
  module Commands
    def self.delete_instance
      instance_id = Env.instance_id
      config_file = Env.config_file
      extra_specs = Env.pool_extra_specs

      raise "GARM_INSTANCE_ID is required for DeleteInstance" if instance_id.empty?

      STDERR.puts "[delete] deleting instance id=#{instance_id}"

      config = ProviderConfig.load(config_file)
      resolved = ResolvedConfig.new(config, extra_specs)
      client = Vultr::Client.new(resolved.api_key)

      # Try deleting by provider_id first. If it looks like a Vultr UUID, use it directly.
      # If it's a garm-generated name (e.g. garm-xxx), search by label/tag.
      if instance_id.includes?("-") && instance_id.size > 30
        # Looks like a Vultr instance UUID
        client.delete_instance(instance_id)
      else
        # Might be a garm instance name; try to find by listing with controller tag
        begin
          client.delete_instance(instance_id)
        rescue ex : Vultr::ApiError
          if ex.not_found? || ex.status_code == 400
            # 404 = not found, 400 = invalid UUID format (garm-generated name)
            # Try finding by name in tagged instances
            controller_id = Env.controller_id
            all = client.list_instances(tag: "#{CONTROLLER_TAG_PREFIX}#{controller_id}")
            found = all.find { |i| i.label == instance_id || i.hostname == instance_id }
            if found
              client.delete_instance(found.id)
            end
            # If not found, it's already deleted - idempotent success
          else
            raise ex
          end
        end
      end

      STDERR.puts "[delete] instance #{instance_id} deleted (or already absent)"
    end
  end
end
