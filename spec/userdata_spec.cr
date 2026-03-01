require "spec"
require "../src/provider/userdata"

describe GarmProviderVultr::UserData do
  describe ".select_tool" do
    tools = [
      GarmProvider::RunnerApplicationDownload.from_json(%({
        "os": "linux", "architecture": "x64",
        "download_url": "https://example.com/linux-x64.tar.gz",
        "filename": "linux-x64.tar.gz", "sha256_checksum": "abc",
        "temp_download_token": ""
      })),
      GarmProvider::RunnerApplicationDownload.from_json(%({
        "os": "linux", "architecture": "arm64",
        "download_url": "https://example.com/linux-arm64.tar.gz",
        "filename": "linux-arm64.tar.gz", "sha256_checksum": "def",
        "temp_download_token": ""
      })),
      GarmProvider::RunnerApplicationDownload.from_json(%({
        "os": "win", "architecture": "x64",
        "download_url": "https://example.com/win-x64.zip",
        "filename": "win-x64.zip", "sha256_checksum": "ghi",
        "temp_download_token": ""
      })),
    ]

    it "selects linux x64 tool for amd64" do
      tool = GarmProviderVultr::UserData.select_tool(tools, "linux", "amd64")
      tool.should_not be_nil
      tool.not_nil!.filename.should eq("linux-x64.tar.gz")
    end

    it "selects linux arm64 tool" do
      tool = GarmProviderVultr::UserData.select_tool(tools, "linux", "arm64")
      tool.should_not be_nil
      tool.not_nil!.filename.should eq("linux-arm64.tar.gz")
    end

    it "selects windows x64 tool" do
      tool = GarmProviderVultr::UserData.select_tool(tools, "windows", "amd64")
      tool.should_not be_nil
      tool.not_nil!.filename.should eq("win-x64.zip")
    end

    it "returns nil for unmatched combo" do
      tool = GarmProviderVultr::UserData.select_tool(tools, "linux", "i386")
      tool.should be_nil
    end
  end

  describe ".generate" do
    it "generates cloud-init for a linux bootstrap" do
      json = %({
        "name": "garm-test",
        "tools": [{
          "os": "linux", "architecture": "x64",
          "download_url": "https://example.com/runner.tar.gz",
          "filename": "runner.tar.gz", "sha256_checksum": "abc",
          "temp_download_token": ""
        }],
        "repo_url": "https://github.com/test/repo",
        "callback-url": "https://garm.example.com/api/v1/callbacks",
        "metadata-url": "https://garm.example.com/api/v1/metadata",
        "instance-token": "test-token",
        "ssh-keys": [],
        "github-runner-group": "",
        "os_type": "linux",
        "arch": "amd64",
        "flavor": "",
        "image": "",
        "labels": ["test"],
        "pool_id": "pool-1",
        "jit_config_enabled": false
      })

      bootstrap = GarmProvider::BootstrapInstance.from_json(json)
      result = GarmProviderVultr::UserData.generate(bootstrap)

      result.should start_with("#cloud-config")
      result.should contain("write_files:")
      result.should contain("runcmd:")
      result.should contain("install_runner.sh")
      result.should contain("packages:")
      result.should contain("  - curl")
      result.should contain("  - tar")
    end

    it "includes extra_packages in cloud-config" do
      json = %({
        "name": "garm-test",
        "tools": [{"os": "linux", "architecture": "x64",
          "download_url": "https://example.com/runner.tar.gz",
          "filename": "runner.tar.gz", "sha256_checksum": "abc",
          "temp_download_token": ""}],
        "repo_url": "https://github.com/test/repo",
        "callback-url": "https://garm.example.com/api/v1/callbacks",
        "metadata-url": "https://garm.example.com/api/v1/metadata",
        "instance-token": "test-token",
        "ssh-keys": [], "github-runner-group": "",
        "os_type": "linux", "arch": "amd64", "flavor": "", "image": "",
        "labels": ["test"], "pool_id": "pool-1", "jit_config_enabled": false
      })

      bootstrap = GarmProvider::BootstrapInstance.from_json(json)
      bootstrap.user_data_options.extra_packages = ["docker.io", "jq"]
      result = GarmProviderVultr::UserData.generate(bootstrap)

      result.should contain("  - docker.io")
      result.should contain("  - jq")
    end

    it "works without extra_packages" do
      json = %({
        "name": "garm-test",
        "tools": [{"os": "linux", "architecture": "x64",
          "download_url": "https://example.com/runner.tar.gz",
          "filename": "runner.tar.gz", "sha256_checksum": "abc",
          "temp_download_token": ""}],
        "repo_url": "https://github.com/test/repo",
        "callback-url": "https://garm.example.com/api/v1/callbacks",
        "metadata-url": "https://garm.example.com/api/v1/metadata",
        "instance-token": "test-token",
        "ssh-keys": [], "github-runner-group": "",
        "os_type": "linux", "arch": "amd64", "flavor": "", "image": "",
        "labels": ["test"], "pool_id": "pool-1", "jit_config_enabled": false
      })

      bootstrap = GarmProvider::BootstrapInstance.from_json(json)
      result = GarmProviderVultr::UserData.generate(bootstrap)

      result.should_not contain("docker.io")
    end
  end
end
