require "json"
require "base64"
require "../config"
require "../vultr/client"
require "../vultr/status_map"
require "../provider/types"
require "../provider/userdata"
require "../util/env"

# CreateInstance command implementation.
# Reads BootstrapInstance from stdin, creates a Vultr instance, returns ProviderInstance JSON on stdout.

module GarmProviderVultr
  module Commands
    def self.create_instance
      controller_id = Env.controller_id
      pool_id = Env.pool_id
      config_file = Env.config_file

      # Read bootstrap params from stdin
      input = STDIN.gets_to_end
      raise "expected bootstrap params in stdin" if input.empty?

      bootstrap = GarmProvider::BootstrapInstance.from_json(input)
      STDERR.puts "[create] creating instance name=#{bootstrap.name} pool=#{pool_id}"

      # Parse extra_specs from bootstrap params (stdin JSON), same as official Go providers
      extra_specs : ExtraSpecs? = nil
      if bs_specs = bootstrap.extra_specs
        begin
          extra_specs = ExtraSpecs.from_json(bs_specs.to_json)
        rescue ex
          STDERR.puts "[create] failed to parse extra_specs: #{ex.message}"
        end
      end

      # Load and resolve config
      config = ProviderConfig.load(config_file)
      resolved = ResolvedConfig.new(config, extra_specs)
      resolved.validate!

      client = Vultr::Client.new(resolved.api_key)

      # Build tags for this instance
      tags = GarmProviderVultr.make_tags(controller_id, pool_id)

      # Merge pool extra_specs into bootstrap user_data_options
      # (GARM core does not populate UserDataOptions; each provider is responsible
      # for extracting these from extra_specs, same as Azure/AWS/OCI/Equinix providers)
      unless resolved.extra_packages.empty?
        bootstrap.user_data_options.extra_packages = resolved.extra_packages
      end
      if resolved.disable_updates
        bootstrap.user_data_options.disable_updates_on_boot = resolved.disable_updates.not_nil!
      end
      if resolved.enable_boot_debug
        bootstrap.user_data_options.enable_boot_debug = resolved.enable_boot_debug.not_nil!
      end

      # Generate cloud-init user data
      user_data = UserData.generate(bootstrap)
      encoded_user_data = Base64.strict_encode(user_data)

      # Build create request
      req = Vultr::CreateInstanceRequest.new(region: resolved.region, plan: resolved.plan)
      req.label = bootstrap.name
      req.hostname = bootstrap.name
      req.tags = tags
      req.user_data = encoded_user_data
      req.sshkey_id = resolved.sshkey_id
      req.enable_ipv6 = resolved.enable_ipv6
      req.firewall_group_id = resolved.firewall_group_id
      req.enable_vpc = resolved.enable_vpc
      req.attach_vpc = resolved.attach_vpc

      # Set OS source
      if resolved.using_image?
        req.image_id = resolved.image_id
      elsif resolved.using_snapshot?
        req.snapshot_id = resolved.snapshot_id
      else
        req.os_id = resolved.os_id
      end

      # Create the instance
      vultr_instance = begin
        client.create_instance(req)
      rescue ex
        # Attempt cleanup on failure if we received a partial instance
        STDERR.puts "[create] failed to create instance: #{ex.message}"
        raise ex
      end

      STDERR.puts "[create] created vultr instance id=#{vultr_instance.id}"

      # Convert to garm ProviderInstance
      result = GarmProviderVultr.vultr_to_garm_instance(vultr_instance)
      # garm only accepts running/stopped/error/unknown from providers.
      # Lifecycle states like creating/deleting are managed by garm itself.
      result = GarmProvider::ProviderInstance.new(
        provider_id: result.provider_id,
        name: result.name,
        os_type: bootstrap.os_type.empty? ? result.os_type : bootstrap.os_type,
        os_name: result.os_name,
        os_version: result.os_version,
        os_arch: GarmProviderVultr.garm_arch_to_os_arch(bootstrap.arch),
        addresses: result.addresses,
        status: GarmProvider::InstanceStatus::Running,
      )

      # Output JSON to stdout
      puts result.to_json
    end
  end
end
