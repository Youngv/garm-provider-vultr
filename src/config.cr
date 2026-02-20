require "json"

# Configuration model for the Vultr provider.
# This is read from the file pointed to by GARM_PROVIDER_CONFIG_FILE.

module GarmProviderVultr
  # ExtraSpecs are per-pool overrides passed via GARM_POOL_EXTRASPECS (base64-encoded JSON).
  struct ExtraSpecs
    include JSON::Serializable

    # Vultr region ID override (e.g. "ewr", "lax")
    property region : String? = nil

    # Vultr plan ID override (e.g. "vc2-1c-1gb")
    property plan : String? = nil

    # Vultr OS ID override (e.g. 1743 for Ubuntu 22.04)
    @[JSON::Field(key: "os_id")]
    property os_id : Int32? = nil

    # Vultr snapshot ID (alternative to os_id)
    @[JSON::Field(key: "snapshot_id")]
    property snapshot_id : String? = nil

    # Vultr image ID (alternative to os_id, for custom images)
    @[JSON::Field(key: "image_id")]
    property image_id : String? = nil

    # SSH key IDs to inject
    @[JSON::Field(key: "sshkey_id")]
    property sshkey_id : Array(String)? = nil

    # Enable IPv6
    @[JSON::Field(key: "enable_ipv6")]
    property enable_ipv6 : Bool? = nil

    # Firewall group ID
    @[JSON::Field(key: "firewall_group_id")]
    property firewall_group_id : String? = nil

    # Cloud-init related
    @[JSON::Field(key: "runner_install_template")]
    property runner_install_template : String? = nil

    @[JSON::Field(key: "extra_context")]
    property extra_context : Hash(String, String)? = nil

    # Enable VPC
    @[JSON::Field(key: "enable_vpc")]
    property enable_vpc : Bool? = nil

    # Attach VPC IDs
    @[JSON::Field(key: "attach_vpc")]
    property attach_vpc : Array(String)? = nil
  end

  # ProviderConfig is the main config file structure (JSON format).
  struct ProviderConfig
    include JSON::Serializable

    # Vultr API key. Can also be set via VULTR_API_KEY env var.
    @[JSON::Field(key: "api_key")]
    property api_key : String = ""

    # Default Vultr region (e.g. "ewr")
    property region : String = ""

    # Default plan (e.g. "vc2-1c-1gb")
    property plan : String = ""

    # Default OS ID (e.g. 1743 for Ubuntu 22.04 x64)
    @[JSON::Field(key: "os_id")]
    property os_id : Int32 = 0

    # Default SSH key IDs
    @[JSON::Field(key: "sshkey_id")]
    property sshkey_id : Array(String) = [] of String

    # Default enable IPv6
    @[JSON::Field(key: "enable_ipv6")]
    property enable_ipv6 : Bool = false

    # Default firewall group ID
    @[JSON::Field(key: "firewall_group_id")]
    property firewall_group_id : String = ""

    # Default enable VPC
    @[JSON::Field(key: "enable_vpc")]
    property enable_vpc : Bool = false

    # Default VPC IDs to attach
    @[JSON::Field(key: "attach_vpc")]
    property attach_vpc : Array(String) = [] of String

    def self.load(path : String) : self
      content = File.read(path)
      from_json(content)
    rescue ex : File::NotFoundError
      raise "config file not found: #{path}"
    rescue ex : JSON::ParseException
      raise "failed to parse config file #{path}: #{ex.message}"
    end

    # Returns the effective API key, preferring env var over config file.
    def effective_api_key : String
      env_key = ENV["VULTR_API_KEY"]? || ""
      key = env_key.empty? ? @api_key : env_key
      raise "Vultr API key not configured. Set VULTR_API_KEY env var or api_key in config." if key.empty?
      key
    end
  end

  # Resolved config merging provider defaults with pool extra_specs overrides.
  struct ResolvedConfig
    property api_key : String
    property region : String
    property plan : String
    property os_id : Int32
    property snapshot_id : String
    property image_id : String
    property sshkey_id : Array(String)
    property enable_ipv6 : Bool
    property firewall_group_id : String
    property enable_vpc : Bool
    property attach_vpc : Array(String)
    property runner_install_template : String?
    property extra_context : Hash(String, String)?

    def initialize(config : ProviderConfig, extra : ExtraSpecs? = nil)
      @api_key = config.effective_api_key
      @region = extra.try(&.region) || config.region
      @plan = extra.try(&.plan) || config.plan
      @os_id = extra.try(&.os_id) || config.os_id
      @snapshot_id = extra.try(&.snapshot_id) || ""
      @image_id = extra.try(&.image_id) || ""
      @sshkey_id = extra.try(&.sshkey_id) || config.sshkey_id
      @enable_ipv6 = extra.try(&.enable_ipv6) || config.enable_ipv6
      @firewall_group_id = extra.try(&.firewall_group_id) || config.firewall_group_id
      @enable_vpc = extra.try(&.enable_vpc) || config.enable_vpc
      @attach_vpc = extra.try(&.attach_vpc) || config.attach_vpc
      @runner_install_template = extra.try(&.runner_install_template)
      @extra_context = extra.try(&.extra_context)
    end

    # Validate that all required fields are present.
    def validate!
      raise "region is required (set in config or pool extra_specs)" if @region.empty?
      raise "plan is required (set in config or pool extra_specs)" if @plan.empty?
      # Must have at least one OS source
      unless @os_id > 0 || !@snapshot_id.empty? || !@image_id.empty?
        raise "OS source is required: set os_id, snapshot_id, or image_id in config or pool extra_specs"
      end
    end

    # Returns true if using a snapshot instead of a standard OS
    def using_snapshot? : Bool
      !@snapshot_id.empty?
    end

    # Returns true if using a custom image
    def using_image? : Bool
      !@image_id.empty?
    end
  end
end
