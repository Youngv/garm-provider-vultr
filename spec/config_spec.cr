require "spec"
require "../src/config"

describe GarmProviderVultr::ProviderConfig do
  it "parses a valid JSON config" do
    json = %({
      "api_key": "test-key-123",
      "region": "ewr",
      "plan": "vc2-1c-1gb",
      "os_id": 1743,
      "sshkey_id": ["key1", "key2"],
      "enable_ipv6": true,
      "firewall_group_id": "fw-123"
    })

    config = GarmProviderVultr::ProviderConfig.from_json(json)
    config.api_key.should eq("test-key-123")
    config.region.should eq("ewr")
    config.plan.should eq("vc2-1c-1gb")
    config.os_id.should eq(1743)
    config.sshkey_id.should eq(["key1", "key2"])
    config.enable_ipv6.should be_true
    config.firewall_group_id.should eq("fw-123")
  end

  it "parses minimal config with defaults" do
    json = %({"region": "lax", "plan": "vc2-1c-1gb", "os_id": 1743})
    config = GarmProviderVultr::ProviderConfig.from_json(json)
    config.api_key.should eq("")
    config.sshkey_id.should eq([] of String)
    config.enable_ipv6.should be_false
  end
end

describe GarmProviderVultr::ExtraSpecs do
  it "parses extra specs with overrides" do
    json = %({
      "region": "lax",
      "plan": "vc2-2c-4gb",
      "os_id": 2136,
      "sshkey_id": ["key-override"]
    })

    specs = GarmProviderVultr::ExtraSpecs.from_json(json)
    specs.region.should eq("lax")
    specs.plan.should eq("vc2-2c-4gb")
    specs.os_id.should eq(2136)
    specs.sshkey_id.should eq(["key-override"])
  end

  it "parses empty extra specs" do
    json = %({"region": null})
    specs = GarmProviderVultr::ExtraSpecs.from_json(json)
    specs.region.should be_nil
    specs.plan.should be_nil
    specs.extra_packages.should be_nil
    specs.disable_updates.should be_nil
    specs.enable_boot_debug.should be_nil
  end

  it "parses extra_packages" do
    json = %({"extra_packages": ["docker.io", "jq"]})
    specs = GarmProviderVultr::ExtraSpecs.from_json(json)
    specs.extra_packages.should eq(["docker.io", "jq"])
  end

  it "parses disable_updates and enable_boot_debug" do
    json = %({"disable_updates": true, "enable_boot_debug": true})
    specs = GarmProviderVultr::ExtraSpecs.from_json(json)
    specs.disable_updates.should be_true
    specs.enable_boot_debug.should be_true
  end
end

describe GarmProviderVultr::ResolvedConfig do
  it "merges extra_specs over provider config" do
    config_json = %({
      "api_key": "key1",
      "region": "ewr",
      "plan": "vc2-1c-1gb",
      "os_id": 1743,
      "sshkey_id": ["default-key"]
    })
    config = GarmProviderVultr::ProviderConfig.from_json(config_json)

    extra_json = %({"region": "lax", "sshkey_id": ["override-key"]})
    extra = GarmProviderVultr::ExtraSpecs.from_json(extra_json)

    resolved = GarmProviderVultr::ResolvedConfig.new(config, extra)
    resolved.region.should eq("lax")
    resolved.plan.should eq("vc2-1c-1gb")
    resolved.os_id.should eq(1743)
    resolved.sshkey_id.should eq(["override-key"])
  end

  it "uses provider defaults when no extra specs" do
    config_json = %({
      "api_key": "key1",
      "region": "ewr",
      "plan": "vc2-1c-1gb",
      "os_id": 1743
    })
    config = GarmProviderVultr::ProviderConfig.from_json(config_json)

    resolved = GarmProviderVultr::ResolvedConfig.new(config, nil)
    resolved.region.should eq("ewr")
    resolved.plan.should eq("vc2-1c-1gb")
    resolved.os_id.should eq(1743)
    resolved.extra_packages.should eq([] of String)
    resolved.disable_updates.should be_nil
    resolved.enable_boot_debug.should be_nil
  end

  it "merges extra_packages from extra specs" do
    config = GarmProviderVultr::ProviderConfig.from_json(%({"api_key": "k", "region": "ewr", "plan": "p", "os_id": 1}))
    extra = GarmProviderVultr::ExtraSpecs.from_json(%({"extra_packages": ["docker.io"]}))
    resolved = GarmProviderVultr::ResolvedConfig.new(config, extra)
    resolved.extra_packages.should eq(["docker.io"])
  end

  it "merges disable_updates and enable_boot_debug from extra specs" do
    config = GarmProviderVultr::ProviderConfig.from_json(%({"api_key": "k", "region": "ewr", "plan": "p", "os_id": 1}))
    extra = GarmProviderVultr::ExtraSpecs.from_json(%({"disable_updates": true, "enable_boot_debug": true}))
    resolved = GarmProviderVultr::ResolvedConfig.new(config, extra)
    resolved.disable_updates.should be_true
    resolved.enable_boot_debug.should be_true
  end

  it "validates required fields" do
    config = GarmProviderVultr::ProviderConfig.from_json(%({"api_key": "k"}))
    resolved = GarmProviderVultr::ResolvedConfig.new(config, nil)
    expect_raises(Exception, /region is required/) do
      resolved.validate!
    end
  end

  it "validates OS source is required" do
    config = GarmProviderVultr::ProviderConfig.from_json(%({"api_key": "k", "region": "ewr", "plan": "p"}))
    resolved = GarmProviderVultr::ResolvedConfig.new(config, nil)
    expect_raises(Exception, /OS source is required/) do
      resolved.validate!
    end
  end
end
