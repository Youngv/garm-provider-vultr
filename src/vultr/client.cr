require "json"
require "http/client"
require "uri"

# Vultr API v2 client using Crystal's stdlib HTTP::Client.

module Vultr
  BASE_URL = "https://api.vultr.com/v2"

  # Vultr API error
  class ApiError < Exception
    getter status_code : Int32
    getter response_body : String

    def initialize(@status_code, @response_body, message : String? = nil)
      super(message || "Vultr API error #{@status_code}: #{@response_body}")
    end

    def not_found? : Bool
      @status_code == 404
    end

    def rate_limited? : Bool
      @status_code == 429
    end

    def server_error? : Bool
      @status_code >= 500
    end

    def retryable? : Bool
      rate_limited? || server_error?
    end
  end

  # Vultr Instance representation
  struct Instance
    include JSON::Serializable

    property id : String = ""
    property os : String = ""
    property ram : Int32 = 0
    property disk : Int32 = 0
    property plan : String = ""

    @[JSON::Field(key: "main_ip")]
    property main_ip : String = ""

    @[JSON::Field(key: "vcpu_count")]
    property vcpu_count : Int32 = 0

    property region : String = ""

    @[JSON::Field(key: "date_created")]
    property date_created : String = ""

    property status : String = ""

    @[JSON::Field(key: "power_status")]
    property power_status : String = ""

    @[JSON::Field(key: "server_status")]
    property server_status : String = ""

    @[JSON::Field(key: "v6_network")]
    property v6_network : String = ""

    @[JSON::Field(key: "v6_main_ip")]
    property v6_main_ip : String = ""

    property label : String = ""

    @[JSON::Field(key: "internal_ip")]
    property internal_ip : String = ""

    @[JSON::Field(key: "os_id")]
    property os_id : Int32 = 0

    @[JSON::Field(key: "app_id")]
    property app_id : Int32 = 0

    @[JSON::Field(key: "image_id")]
    property image_id : String = ""

    @[JSON::Field(key: "snapshot_id")]
    property snapshot_id : String = ""

    property hostname : String = ""
    property tags : Array(String) = [] of String

    @[JSON::Field(key: "user_scheme")]
    property user_scheme : String = ""
  end

  struct InstanceWrapper
    include JSON::Serializable
    property instance : Instance
  end

  struct InstanceListWrapper
    include JSON::Serializable
    property instances : Array(Instance) = [] of Instance
    property meta : Meta? = nil
  end

  struct Meta
    include JSON::Serializable
    property total : Int32 = 0
    property links : Links? = nil
  end

  struct Links
    include JSON::Serializable
    property next : String = ""
    property prev : String = ""
  end

  struct CreateInstanceRequest
    include JSON::Serializable

    property region : String
    property plan : String
    property label : String = ""
    property tags : Array(String) = [] of String

    @[JSON::Field(key: "os_id")]
    property os_id : Int32 = 0

    @[JSON::Field(key: "snapshot_id")]
    property snapshot_id : String = ""

    @[JSON::Field(key: "image_id")]
    property image_id : String = ""

    @[JSON::Field(key: "sshkey_id")]
    property sshkey_id : Array(String) = [] of String

    @[JSON::Field(key: "enable_ipv6")]
    property enable_ipv6 : Bool = false

    @[JSON::Field(key: "firewall_group_id")]
    property firewall_group_id : String = ""

    property hostname : String = ""

    @[JSON::Field(key: "user_data")]
    property user_data : String = ""

    @[JSON::Field(key: "enable_vpc")]
    property enable_vpc : Bool = false

    @[JSON::Field(key: "attach_vpc")]
    property attach_vpc : Array(String) = [] of String

    def initialize(@region, @plan)
    end
  end

  class Client
    MAX_RETRIES     = 3
    RETRY_BASE_SECS = 2

    def initialize(@api_key : String)
      @base_uri = URI.parse(BASE_URL)
    end

    # Create a new instance
    def create_instance(req : CreateInstanceRequest) : Instance
      body = build_create_body(req)
      response = request("POST", "/instances", body)
      wrapper = InstanceWrapper.from_json(response)
      wrapper.instance
    end

    # Get instance by ID
    def get_instance(instance_id : String) : Instance
      response = request("GET", "/instances/#{URI.encode_path(instance_id)}")
      wrapper = InstanceWrapper.from_json(response)
      wrapper.instance
    end

    # List all instances, optionally filtered by tag
    def list_instances(tag : String? = nil) : Array(Instance)
      all_instances = [] of Instance
      cursor = ""

      loop do
        path = "/instances?per_page=100"
        path += "&tag=#{URI.encode_www_form(tag)}" if tag
        path += "&cursor=#{URI.encode_www_form(cursor)}" unless cursor.empty?

        response = request("GET", path)
        wrapper = InstanceListWrapper.from_json(response)
        all_instances.concat(wrapper.instances)

        next_cursor = wrapper.meta.try(&.links).try(&.next) || ""
        break if next_cursor.empty?
        cursor = next_cursor
      end

      all_instances
    end

    # Delete an instance
    def delete_instance(instance_id : String) : Nil
      request("DELETE", "/instances/#{URI.encode_path(instance_id)}")
      nil
    rescue ex : ApiError
      raise ex unless ex.not_found?
      # Not found is a no-op for delete (idempotent)
      nil
    end

    # Start (reboot/restart) an instance
    def start_instance(instance_id : String) : Nil
      request("POST", "/instances/#{URI.encode_path(instance_id)}/start")
      nil
    end

    # Halt (stop) an instance
    def halt_instance(instance_id : String) : Nil
      request("POST", "/instances/#{URI.encode_path(instance_id)}/halt")
      nil
    end

    private def request(method : String, path : String, body : String? = nil) : String
      retries = 0

      loop do
        response = execute_http(method, path, body)

        case response.status_code
        when 200, 201, 202, 204
          return response.body
        when 404
          raise ApiError.new(response.status_code, response.body)
        when 429, 500..599
          retries += 1
          if retries > MAX_RETRIES
            raise ApiError.new(response.status_code, response.body,
              "Vultr API error after #{MAX_RETRIES} retries: #{response.status_code}")
          end
          wait_secs = RETRY_BASE_SECS * (2 ** (retries - 1))
          STDERR.puts "[vultr] retryable error #{response.status_code}, retry #{retries}/#{MAX_RETRIES} in #{wait_secs}s"
          sleep(wait_secs.seconds)
        else
          raise ApiError.new(response.status_code, response.body)
        end
      end
    end

    private def execute_http(method : String, path : String, body : String? = nil) : HTTP::Client::Response
      headers = HTTP::Headers{
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type"  => "application/json",
        "Accept"        => "application/json",
      }

      tls = OpenSSL::SSL::Context::Client.new
      client = HTTP::Client.new(@base_uri.host.not_nil!, port: 443, tls: tls)
      client.read_timeout = 30.seconds
      client.connect_timeout = 10.seconds

      full_path = "/v2#{path}"

      case method.upcase
      when "GET"
        client.get(full_path, headers: headers)
      when "POST"
        client.post(full_path, headers: headers, body: body)
      when "DELETE"
        client.delete(full_path, headers: headers)
      when "PATCH"
        client.patch(full_path, headers: headers, body: body)
      else
        raise "unsupported HTTP method: #{method}"
      end
    ensure
      client.try(&.close)
    end

    # Build the JSON body for create instance, omitting empty/zero optional fields
    private def build_create_body(req : CreateInstanceRequest) : String
      JSON.build do |json|
        json.object do
          json.field "region", req.region
          json.field "plan", req.plan
          json.field "label", req.label unless req.label.empty?
          json.field "hostname", req.hostname unless req.hostname.empty?
          json.field "tags", req.tags unless req.tags.empty?
          json.field "os_id", req.os_id if req.os_id > 0
          json.field "snapshot_id", req.snapshot_id unless req.snapshot_id.empty?
          json.field "image_id", req.image_id unless req.image_id.empty?
          json.field "sshkey_id", req.sshkey_id unless req.sshkey_id.empty?
          json.field "enable_ipv6", req.enable_ipv6 if req.enable_ipv6
          json.field "firewall_group_id", req.firewall_group_id unless req.firewall_group_id.empty?
          json.field "user_data", req.user_data unless req.user_data.empty?
          json.field "enable_vpc", req.enable_vpc if req.enable_vpc
          json.field "attach_vpc", req.attach_vpc unless req.attach_vpc.empty?
        end
      end
    end
  end
end
