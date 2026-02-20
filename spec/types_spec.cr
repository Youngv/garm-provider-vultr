require "spec"
require "../src/provider/types"

describe GarmProvider::BootstrapInstance do
  it "deserializes garm bootstrap JSON" do
    json = %({
      "name": "garm-test-runner",
      "tools": [
        {
          "os": "linux",
          "architecture": "x64",
          "download_url": "https://example.com/runner.tar.gz",
          "filename": "runner.tar.gz",
          "sha256_checksum": "abc123",
          "temp_download_token": ""
        }
      ],
      "repo_url": "https://github.com/test/repo",
      "callback-url": "https://garm.example.com/api/v1/callbacks",
      "metadata-url": "https://garm.example.com/api/v1/metadata",
      "instance-token": "jwt-token-here",
      "ssh-keys": ["ssh-rsa AAAA..."],
      "extra_specs": {"region": "ewr"},
      "github-runner-group": "",
      "ca-cert-bundle": null,
      "os_type": "linux",
      "arch": "amd64",
      "flavor": "vc2-1c-1gb",
      "image": "ubuntu-22.04",
      "labels": ["ubuntu", "vultr"],
      "pool_id": "pool-123",
      "jit_config_enabled": false
    })

    bootstrap = GarmProvider::BootstrapInstance.from_json(json)
    bootstrap.name.should eq("garm-test-runner")
    bootstrap.tools.size.should eq(1)
    bootstrap.tools[0].os.should eq("linux")
    bootstrap.tools[0].architecture.should eq("x64")
    bootstrap.repo_url.should eq("https://github.com/test/repo")
    bootstrap.callback_url.should eq("https://garm.example.com/api/v1/callbacks")
    bootstrap.metadata_url.should eq("https://garm.example.com/api/v1/metadata")
    bootstrap.instance_token.should eq("jwt-token-here")
    bootstrap.ssh_keys.should eq(["ssh-rsa AAAA..."])
    bootstrap.os_type.should eq("linux")
    bootstrap.arch.should eq("amd64")
    bootstrap.labels.should eq(["ubuntu", "vultr"])
    bootstrap.pool_id.should eq("pool-123")
    bootstrap.jit_config_enabled.should be_false
  end
end

describe GarmProvider::ProviderInstance do
  it "serializes to expected JSON format" do
    instance = GarmProvider::ProviderInstance.new(
      provider_id: "vultr-123",
      name: "garm-test",
      os_type: "linux",
      os_name: "ubuntu",
      os_version: "22.04",
      os_arch: "x86_64",
      status: GarmProvider::InstanceStatus::Running,
    )

    json = JSON.parse(instance.to_json)
    json["provider_id"].as_s.should eq("vultr-123")
    json["name"].as_s.should eq("garm-test")
    json["os_type"].as_s.should eq("linux")
    json["os_name"].as_s.should eq("ubuntu")
    json["os_version"].as_s.should eq("22.04")
    json["os_arch"].as_s.should eq("x86_64")
    json["status"].as_s.should eq("running")
  end

  it "serializes addresses" do
    instance = GarmProvider::ProviderInstance.new(
      provider_id: "vultr-123",
      name: "test",
      addresses: [
        GarmProvider::Address.new(address: "1.2.3.4", type: GarmProvider::AddressType::Public),
        GarmProvider::Address.new(address: "10.0.0.1", type: GarmProvider::AddressType::Private),
      ],
      status: GarmProvider::InstanceStatus::Running,
    )

    json = JSON.parse(instance.to_json)
    addrs = json["addresses"].as_a
    addrs.size.should eq(2)
    addrs[0]["address"].as_s.should eq("1.2.3.4")
    addrs[0]["type"].as_s.should eq("public")
    addrs[1]["type"].as_s.should eq("private")
  end
end
