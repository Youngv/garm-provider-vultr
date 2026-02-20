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
