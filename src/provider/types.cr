require "json"

# garm provider types matching the garm-provider-common params package.
# These are the structures garm expects for communication with external providers.

module GarmProvider
  # Instance status values matching garm-provider-common/params
  enum InstanceStatus
    Running
    Stopped
    Error
    PendingDelete
    PendingForceDelete
    Deleting
    Deleted
    PendingCreate
    Creating
    Unknown

    def to_json(json : JSON::Builder)
      json.string(to_s.underscore)
    end

    def self.from_s(str : String) : self
      case str.downcase
      when "running"              then Running
      when "stopped"              then Stopped
      when "error"                then Error
      when "pending_delete"       then PendingDelete
      when "pending_force_delete" then PendingForceDelete
      when "deleting"             then Deleting
      when "deleted"              then Deleted
      when "pending_create"       then PendingCreate
      when "creating"             then Creating
      else                             Unknown
      end
    end
  end

  enum AddressType
    Public
    Private

    def to_json(json : JSON::Builder)
      json.string(to_s.downcase)
    end
  end

  struct Address
    include JSON::Serializable

    property address : String
    property type : AddressType

    def initialize(@address, @type)
    end
  end

  # ProviderInstance is the structure returned by CreateInstance, GetInstance, and ListInstances.
  struct ProviderInstance
    include JSON::Serializable

    @[JSON::Field(key: "provider_id")]
    property provider_id : String = ""

    property name : String = ""

    @[JSON::Field(key: "os_type")]
    property os_type : String = ""

    @[JSON::Field(key: "os_name")]
    property os_name : String = ""

    @[JSON::Field(key: "os_version")]
    property os_version : String = ""

    @[JSON::Field(key: "os_arch")]
    property os_arch : String = ""

    property addresses : Array(Address) = [] of Address

    property status : InstanceStatus = InstanceStatus::Unknown

    @[JSON::Field(key: "provider_fault")]
    property provider_fault : String = ""

    def initialize(
      @provider_id = "",
      @name = "",
      @os_type = "",
      @os_name = "",
      @os_version = "",
      @os_arch = "",
      @addresses = [] of Address,
      @status = InstanceStatus::Unknown,
      @provider_fault = ""
    )
    end
  end

  # RunnerApplicationDownload is tool info from garm's BootstrapInstance
  struct RunnerApplicationDownload
    include JSON::Serializable

    property os : String = ""
    property architecture : String = ""

    @[JSON::Field(key: "download_url")]
    property download_url : String = ""

    property filename : String = ""

    @[JSON::Field(key: "sha256_checksum")]
    property sha256_checksum : String = ""

    @[JSON::Field(key: "temp_download_token")]
    property temp_download_token : String = ""
  end

  struct UserDataOptions
    include JSON::Serializable

    @[JSON::Field(key: "disable_updates_on_boot")]
    property disable_updates_on_boot : Bool = false

    @[JSON::Field(key: "extra_packages")]
    property extra_packages : Array(String) = [] of String

    @[JSON::Field(key: "enable_boot_debug")]
    property enable_boot_debug : Bool = false

    def initialize(
      @disable_updates_on_boot = false,
      @extra_packages = [] of String,
      @enable_boot_debug = false
    )
    end
  end

  # BootstrapInstance is the JSON sent via stdin for CreateInstance
  struct BootstrapInstance
    include JSON::Serializable

    property name : String = ""
    property tools : Array(RunnerApplicationDownload) = [] of RunnerApplicationDownload

    @[JSON::Field(key: "repo_url")]
    property repo_url : String = ""

    @[JSON::Field(key: "callback-url")]
    property callback_url : String = ""

    @[JSON::Field(key: "metadata-url")]
    property metadata_url : String = ""

    @[JSON::Field(key: "instance-token")]
    property instance_token : String = ""

    @[JSON::Field(key: "ssh-keys")]
    property ssh_keys : Array(String) = [] of String

    @[JSON::Field(key: "extra_specs")]
    property extra_specs : JSON::Any? = nil

    @[JSON::Field(key: "github-runner-group")]
    property github_runner_group : String = ""

    @[JSON::Field(key: "ca-cert-bundle")]
    property ca_cert_bundle : String? = nil

    @[JSON::Field(key: "os_type")]
    property os_type : String = ""

    property arch : String = ""
    property flavor : String = ""
    property image : String = ""
    property labels : Array(String) = [] of String

    @[JSON::Field(key: "pool_id")]
    property pool_id : String = ""

    @[JSON::Field(key: "user_data_options")]
    property user_data_options : UserDataOptions = UserDataOptions.new

    @[JSON::Field(key: "jit_config_enabled")]
    property jit_config_enabled : Bool = false
  end
end
