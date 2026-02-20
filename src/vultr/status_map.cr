require "../provider/types"

# Maps Vultr instance states to garm InstanceStatus.

module GarmProviderVultr
  # Map Vultr instance status + power_status to garm InstanceStatus
  def self.map_vultr_status(vultr_status : String, power_status : String) : GarmProvider::InstanceStatus
    case vultr_status
    when "active"
      case power_status
      when "running" then GarmProvider::InstanceStatus::Running
      when "stopped" then GarmProvider::InstanceStatus::Stopped
      else                GarmProvider::InstanceStatus::Running
      end
    when "pending"   then GarmProvider::InstanceStatus::Creating
    when "suspended" then GarmProvider::InstanceStatus::Stopped
    when "resizing"  then GarmProvider::InstanceStatus::Creating
    else                  GarmProvider::InstanceStatus::Unknown
    end
  end

  # Map Vultr OS string to garm os_name / os_version
  def self.parse_os_info(os_label : String) : {String, String}
    # Vultr OS labels look like "Ubuntu 22.04 x64", "Debian 12 x64", "CentOS 9 Stream x64"
    parts = os_label.split(' ', limit: 3)
    name = parts[0]? || ""
    version = parts[1]? || ""
    {name.downcase, version}
  end

  # Map garm arch to Vultr-compatible arch string
  def self.garm_arch_to_os_arch(arch : String) : String
    case arch.downcase
    when "amd64", "x86_64"  then "x86_64"
    when "arm64", "aarch64" then "arm64"
    when "arm"              then "arm"
    when "i386", "386"      then "i386"
    else                         arch
    end
  end

  # Convert a Vultr Instance to a garm ProviderInstance
  def self.vultr_to_garm_instance(vi : Vultr::Instance) : GarmProvider::ProviderInstance
    os_name, os_version = parse_os_info(vi.os)
    status = map_vultr_status(vi.status, vi.power_status)

    addresses = [] of GarmProvider::Address
    unless vi.main_ip.empty? || vi.main_ip == "0.0.0.0"
      addresses << GarmProvider::Address.new(address: vi.main_ip, type: GarmProvider::AddressType::Public)
    end
    unless vi.v6_main_ip.empty?
      addresses << GarmProvider::Address.new(address: vi.v6_main_ip, type: GarmProvider::AddressType::Public)
    end
    unless vi.internal_ip.empty?
      addresses << GarmProvider::Address.new(address: vi.internal_ip, type: GarmProvider::AddressType::Private)
    end

    # Determine arch from OS label (Vultr tags x64/arm64 in the OS name)
    os_arch = "x86_64"
    os_lower = vi.os.downcase
    if os_lower.includes?("arm64") || os_lower.includes?("aarch64")
      os_arch = "arm64"
    elsif os_lower.includes?("arm")
      os_arch = "arm"
    elsif os_lower.includes?("i386") || os_lower.includes?("x86")
      os_arch = "i386"
    end

    GarmProvider::ProviderInstance.new(
      provider_id: vi.id,
      name: vi.label.empty? ? vi.hostname : vi.label,
      os_type: "linux", # Vultr primarily Linux for runners
      os_name: os_name,
      os_version: os_version,
      os_arch: os_arch,
      addresses: addresses,
      status: status,
    )
  end

  # Tag constants
  CONTROLLER_TAG_PREFIX = "garm-controller-id:"
  POOL_TAG_PREFIX       = "garm-pool-id:"

  # Generate tags for a Vultr instance
  def self.make_tags(controller_id : String, pool_id : String) : Array(String)
    tags = [] of String
    tags << "#{CONTROLLER_TAG_PREFIX}#{controller_id}"
    tags << "#{POOL_TAG_PREFIX}#{pool_id}" unless pool_id.empty?
    tags
  end

  # Extract pool ID from instance tags
  def self.pool_id_from_tags(tags : Array(String)) : String?
    tags.each do |tag|
      return tag.sub(POOL_TAG_PREFIX, "") if tag.starts_with?(POOL_TAG_PREFIX)
    end
    nil
  end

  # Check if instance belongs to this controller
  def self.belongs_to_controller?(tags : Array(String), controller_id : String) : Bool
    tags.any? { |tag| tag == "#{CONTROLLER_TAG_PREFIX}#{controller_id}" }
  end

  # Check if instance belongs to specific pool
  def self.belongs_to_pool?(tags : Array(String), pool_id : String) : Bool
    tags.any? { |tag| tag == "#{POOL_TAG_PREFIX}#{pool_id}" }
  end
end
