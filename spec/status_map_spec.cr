require "spec"
require "../src/vultr/status_map"

describe GarmProviderVultr do
  describe ".map_vultr_status" do
    it "maps active+running to Running" do
      status = GarmProviderVultr.map_vultr_status("active", "running")
      status.should eq(GarmProvider::InstanceStatus::Running)
    end

    it "maps active+stopped to Stopped" do
      status = GarmProviderVultr.map_vultr_status("active", "stopped")
      status.should eq(GarmProvider::InstanceStatus::Stopped)
    end

    it "maps pending to Creating" do
      status = GarmProviderVultr.map_vultr_status("pending", "")
      status.should eq(GarmProvider::InstanceStatus::Creating)
    end

    it "maps suspended to Stopped" do
      status = GarmProviderVultr.map_vultr_status("suspended", "")
      status.should eq(GarmProvider::InstanceStatus::Stopped)
    end

    it "maps unknown status to Unknown" do
      status = GarmProviderVultr.map_vultr_status("foo", "bar")
      status.should eq(GarmProvider::InstanceStatus::Unknown)
    end
  end

  describe ".parse_os_info" do
    it "parses Ubuntu 22.04 x64" do
      name, version = GarmProviderVultr.parse_os_info("Ubuntu 22.04 x64")
      name.should eq("ubuntu")
      version.should eq("22.04")
    end

    it "parses Debian 12 x64" do
      name, version = GarmProviderVultr.parse_os_info("Debian 12 x64")
      name.should eq("debian")
      version.should eq("12")
    end

    it "handles empty string" do
      name, version = GarmProviderVultr.parse_os_info("")
      name.should eq("")
      version.should eq("")
    end
  end

  describe ".make_tags" do
    it "generates correct tags" do
      tags = GarmProviderVultr.make_tags("ctrl-123", "pool-456")
      tags.should eq(["garm-controller-id:ctrl-123", "garm-pool-id:pool-456"])
    end

    it "skips pool tag when empty" do
      tags = GarmProviderVultr.make_tags("ctrl-123", "")
      tags.should eq(["garm-controller-id:ctrl-123"])
    end
  end

  describe ".belongs_to_controller?" do
    it "returns true when tag matches" do
      tags = ["garm-controller-id:abc", "garm-pool-id:def"]
      GarmProviderVultr.belongs_to_controller?(tags, "abc").should be_true
    end

    it "returns false when tag doesn't match" do
      tags = ["garm-controller-id:abc"]
      GarmProviderVultr.belongs_to_controller?(tags, "xyz").should be_false
    end
  end

  describe ".belongs_to_pool?" do
    it "returns true when pool tag matches" do
      tags = ["garm-controller-id:abc", "garm-pool-id:def"]
      GarmProviderVultr.belongs_to_pool?(tags, "def").should be_true
    end
  end

  describe ".pool_id_from_tags" do
    it "extracts pool id from tags" do
      tags = ["garm-controller-id:abc", "garm-pool-id:def"]
      GarmProviderVultr.pool_id_from_tags(tags).should eq("def")
    end

    it "returns nil when no pool tag" do
      tags = ["garm-controller-id:abc"]
      GarmProviderVultr.pool_id_from_tags(tags).should be_nil
    end
  end
end
