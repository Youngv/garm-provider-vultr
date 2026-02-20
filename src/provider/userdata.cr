require "base64"
require "../provider/types"

# Generates cloud-init user data for bootstrapping garm runners on Vultr instances.
# This follows the same pattern as garm-provider-common/cloudconfig but implemented in Crystal.

module GarmProviderVultr
  module UserData
    # Select the appropriate runner tool download for the given OS type and architecture.
    def self.select_tool(tools : Array(GarmProvider::RunnerApplicationDownload), os_type : String, arch : String) : GarmProvider::RunnerApplicationDownload?
      # Normalize arch for matching
      normalized_arch = case arch.downcase
                        when "amd64", "x86_64"  then "x64"
                        when "arm64", "aarch64" then "arm64"
                        when "arm"              then "arm"
                        when "i386", "386"      then "x86"
                        else                         arch
                        end

      normalized_os = case os_type.downcase
                      when "linux"   then "linux"
                      when "windows" then "win"
                      when "osx"     then "osx"
                      else                os_type.downcase
                      end

      tools.find { |t| t.os == normalized_os && t.architecture == normalized_arch }
    end

    # Generate the cloud-init user data string for a Linux instance.
    def self.generate(bootstrap : GarmProvider::BootstrapInstance) : String
      tool = select_tool(bootstrap.tools, bootstrap.os_type, bootstrap.arch)
      raise "no matching runner tool found for os=#{bootstrap.os_type} arch=#{bootstrap.arch}" unless tool

      runner_labels = bootstrap.labels.join(",")
      use_jit = bootstrap.jit_config_enabled

      install_script = generate_install_script(
        filename: tool.filename,
        download_url: tool.download_url,
        temp_download_token: tool.temp_download_token,
        metadata_url: bootstrap.metadata_url,
        runner_name: bootstrap.name,
        runner_labels: runner_labels,
        callback_url: bootstrap.callback_url,
        callback_token: bootstrap.instance_token,
        repo_url: bootstrap.repo_url,
        github_runner_group: bootstrap.github_runner_group,
        enable_boot_debug: bootstrap.user_data_options.enable_boot_debug,
        use_jit_config: use_jit,
        ca_bundle: bootstrap.ca_cert_bundle,
      )

      cloud_config = generate_cloud_config(
        install_script: install_script,
        ssh_keys: bootstrap.ssh_keys,
        ca_cert_bundle: bootstrap.ca_cert_bundle,
        extra_packages: bootstrap.user_data_options.extra_packages,
        disable_updates: bootstrap.user_data_options.disable_updates_on_boot,
      )

      cloud_config
    end

    private def self.generate_cloud_config(
      install_script : String,
      ssh_keys : Array(String),
      ca_cert_bundle : String?,
      extra_packages : Array(String),
      disable_updates : Bool
    ) : String
      lines = ["#cloud-config"]
      lines << "package_upgrade: #{!disable_updates}"
      lines << "packages:"
      unless disable_updates
        lines << "  - curl"
        lines << "  - tar"
      end
      extra_packages.each do |pkg|
        lines << "  - #{pkg}"
      end

      # Create the runner user via cloud-init (mirrors garm-provider-common defaults)
      lines << "users:"
      lines << "  - default"
      lines << "system_info:"
      lines << "  default_user:"
      lines << "    name: runner"
      lines << "    home: /home/runner"
      lines << "    shell: /bin/bash"
      lines << "    groups:"
      lines << "      - sudo"
      lines << "      - adm"
      lines << "      - cdrom"
      lines << "      - dialout"
      lines << "      - dip"
      lines << "      - video"
      lines << "      - plugdev"
      lines << "      - netdev"
      lines << "      - docker"
      lines << "      - lxd"
      lines << "    sudo: ALL=(ALL) NOPASSWD:ALL"

      unless ssh_keys.empty?
        lines << "ssh_authorized_keys:"
        ssh_keys.each do |key|
          lines << "  - #{key}"
        end
      end

      # Write install script as a file
      encoded_script = Base64.strict_encode(install_script)
      lines << "write_files:"
      lines << "  - encoding: b64"
      lines << "    content: #{encoded_script}"
      lines << "    owner: root:root"
      lines << "    path: /install_runner.sh"
      lines << "    permissions: '0755'"

      # CA cert bundle
      if ca_cert_bundle && !ca_cert_bundle.empty?
        lines << "ca-certs:"
        lines << "  trusted:"
        lines << "    - |"
        ca_cert_bundle.each_line do |line|
          lines << "      #{line}"
        end
      end

      lines << "runcmd:"
      lines << "  - su -l -c /install_runner.sh runner"
      lines << "  - rm -f /install_runner.sh"

      lines.join("\n") + "\n"
    end

    private def self.generate_install_script(
      filename : String,
      download_url : String,
      temp_download_token : String,
      metadata_url : String,
      runner_name : String,
      runner_labels : String,
      callback_url : String,
      callback_token : String,
      repo_url : String,
      github_runner_group : String,
      enable_boot_debug : Bool,
      use_jit_config : Bool,
      ca_bundle : String?
    ) : String
      # This generates a bash script that mirrors garm-provider-common's CloudConfigTemplate
      script = String.build do |s|
        s << "#!/bin/bash\n\n"
        s << "set -e\n"
        s << "set -o pipefail\n"
        s << "set -x\n" if enable_boot_debug
        s << "\n"
        s << "CALLBACK_URL=\"#{callback_url}\"\n"
        s << "METADATA_URL=\"#{metadata_url}\"\n"
        s << "BEARER_TOKEN=\"#{callback_token}\"\n"
        s << "\n"
        s << "RUNNER_USERNAME=\"runner\"\n"
        s << "RUNNER_GROUP=\"runner\"\n"
        s << "RUN_HOME=\"/home/${RUNNER_USERNAME}/actions-runner\"\n"
        s << "\n"
        s << <<-'BASH'
        if [ -z "$METADATA_URL" ];then
        	echo "no token is available and METADATA_URL is not set"
        	exit 1
        fi

        function call() {
        	PAYLOAD="$1"
        	[[ $CALLBACK_URL =~ ^(.*)/status(/)?$ ]] || CALLBACK_URL="${CALLBACK_URL}/status"
        	curl --retry 5 --retry-delay 5 --retry-connrefused --fail -s -X POST -d "${PAYLOAD}" -H 'Accept: application/json' -H "Authorization: Bearer ${BEARER_TOKEN}" "${CALLBACK_URL}" || echo "failed to call home: exit code ($?)"
        }

        function systemInfo() {
        	if [ -f "/etc/os-release" ];then
        		. /etc/os-release
        	fi
        	OS_NAME=${NAME:-""}
        	OS_VERSION=${VERSION_ID:-""}
        	AGENT_ID=${1:-null}
        	[[ $CALLBACK_URL =~ ^(.*)/status(/)?$ ]] && CALLBACK_URL="${BASH_REMATCH[1]}" || true
        	SYSINFO_URL="${CALLBACK_URL}/system-info/"
        	PAYLOAD="{\"os_name\": \"$OS_NAME\", \"os_version\": \"$OS_VERSION\", \"agent_id\": $AGENT_ID}"
        	curl --retry 5 --retry-delay 5 --retry-connrefused --fail -s -X POST -d "${PAYLOAD}" -H 'Accept: application/json' -H "Authorization: Bearer ${BEARER_TOKEN}" "${SYSINFO_URL}" || true
        }

        function sendStatus() {
        	MSG="$1"
        	call "{\"status\": \"installing\", \"message\": \"$MSG\"}"
        }

        function success() {
        	MSG="$1"
        	ID=${2:-null}
        	call "{\"status\": \"idle\", \"message\": \"$MSG\", \"agent_id\": $ID}"
        }

        function fail() {
        	MSG="$1"
        	call "{\"status\": \"failed\", \"message\": \"$MSG\"}"
        	exit 1
        }

        function downloadAndExtractRunner() {
        BASH
        s << "\n"
        s << "\tsendStatus \"downloading tools from #{download_url}\"\n"

        unless temp_download_token.empty?
          s << "\tTEMP_TOKEN=\"Authorization: Bearer #{temp_download_token}\"\n"
        end

        s << "\tcurl --retry 5 --retry-delay 5 --retry-connrefused --fail -L"
        s << " -H \"${TEMP_TOKEN}\"" unless temp_download_token.empty?
        s << " -o \"/home/${RUNNER_USERNAME}/#{filename}\" \"#{download_url}\" || fail \"failed to download tools\"\n"
        s << "\tmkdir -p \"$RUN_HOME\" || fail \"failed to create actions-runner folder\"\n"
        s << "\tsendStatus \"extracting runner\"\n"
        s << "\ttar xf \"/home/${RUNNER_USERNAME}/#{filename}\" -C \"$RUN_HOME\"/ || fail \"failed to extract runner\"\n"
        s << "\tchown ${RUNNER_USERNAME}:${RUNNER_GROUP} -R \"$RUN_HOME\"/ || fail \"failed to change owner\"\n"
        s << "}\n\n"

        s << <<-'BASH'
        if [ ! -d "$RUN_HOME" ];then
        	downloadAndExtractRunner
        	sendStatus "installing dependencies"
        	cd "$RUN_HOME"
        	attempt=1
        	while true; do
        		sudo ./bin/installdependencies.sh && break
        		if [ $attempt -gt 5 ];then
        			fail "failed to install dependencies after $attempt attempts"
        		fi
        		sendStatus "failed to install dependencies (attempt $attempt): (retrying in 15 seconds)"
        		attempt=$((attempt+1))
        		sleep 15
        	done
        else
        	sendStatus "using cached runner found in $RUN_HOME"
        	cd "$RUN_HOME"
        fi

        sendStatus "configuring runner"
        BASH
        s << "\n"

        if use_jit_config
          s << <<-'BASH'
          function getRunnerFile() {
          	curl --retry 5 --retry-delay 5 \
          		--retry-connrefused --fail -s \
          		-X GET -H 'Accept: application/json' \
          		-H "Authorization: Bearer ${BEARER_TOKEN}" \
          		"${METADATA_URL}/$1" -o "$2"
          }

          sendStatus "downloading JIT credentials"
          getRunnerFile "credentials/runner" "$RUN_HOME/.runner" || fail "failed to get runner file"
          getRunnerFile "credentials/credentials" "$RUN_HOME/.credentials" || fail "failed to get credentials file"
          getRunnerFile "credentials/credentials_rsaparams" "$RUN_HOME/.credentials_rsaparams" || fail "failed to get credentials_rsaparams file"
          getRunnerFile "system/service-name" "$RUN_HOME/.service" || fail "failed to get service name file"
          sed -i 's/$/\.service/' "$RUN_HOME/.service"

          SVC_NAME=$(cat "$RUN_HOME/.service")

          sendStatus "generating systemd unit file"
          getRunnerFile "systemd/unit-file?runAsUser=${RUNNER_USERNAME}" "$SVC_NAME" || fail "failed to get service file"
          sudo mv $SVC_NAME /etc/systemd/system/ || fail "failed to move service file"
          sudo chown root:root /etc/systemd/system/$SVC_NAME || fail "failed to change owner"

          if [ -e "/sys/fs/selinux" ];then
          	sudo chcon -h system_u:object_r:systemd_unit_file_t:s0 /etc/systemd/system/$SVC_NAME || fail "failed to change selinux context"
          fi

          sendStatus "enabling runner service"
          cp "$RUN_HOME"/bin/runsvc.sh "$RUN_HOME"/ || fail "failed to copy runsvc.sh"
          sudo chown ${RUNNER_USERNAME}:${RUNNER_GROUP} -R /home/${RUNNER_USERNAME} || fail "failed to change owner"
          sudo systemctl daemon-reload || fail "failed to reload systemd"
          sudo systemctl enable $SVC_NAME
          BASH
          s << "\n"
        else
          # Token-based registration
          s << "GITHUB_TOKEN=$(curl --retry 5 --retry-delay 5 --retry-connrefused --fail -s -X GET -H 'Accept: application/json' -H \"Authorization: Bearer ${BEARER_TOKEN}\" \"${METADATA_URL}/runner-registration-token/\")\n\n"
          s << "set +e\n"
          s << "attempt=1\n"
          s << "while true; do\n"
          s << "\tERROUT=$(mktemp)\n"

          config_args = "--unattended --url \"#{repo_url}\" --token \"$GITHUB_TOKEN\""
          config_args += " --runnergroup #{github_runner_group}" unless github_runner_group.empty?
          config_args += " --name \"#{runner_name}\" --labels \"#{runner_labels}\" --no-default-labels --ephemeral"

          s << "\t./config.sh #{config_args} 2>$ERROUT\n"
          s << "\tif [ $? -eq 0 ]; then\n"
          s << "\t\trm $ERROUT || true\n"
          s << "\t\tsendStatus \"runner successfully configured after $attempt attempt(s)\"\n"
          s << "\t\tbreak\n"
          s << "\tfi\n"
          s << "\tLAST_ERR=$(cat $ERROUT)\n"
          s << "\techo \"$LAST_ERR\"\n"
          s << "\t./config.sh remove --token \"$GITHUB_TOKEN\" || true\n"
          s << "\tif [ $attempt -gt 5 ];then\n"
          s << "\t\trm $ERROUT || true\n"
          s << "\t\tfail \"failed to configure runner: $LAST_ERR\"\n"
          s << "\tfi\n"
          s << "\tsendStatus \"failed to configure runner (attempt $attempt): $LAST_ERR (retrying in 5 seconds)\"\n"
          s << "\tattempt=$((attempt+1))\n"
          s << "\trm $ERROUT || true\n"
          s << "\tsleep 5\n"
          s << "done\n"
          s << "set -e\n\n"

          s << "sendStatus \"installing runner service\"\n"
          s << "sudo ./svc.sh install ${RUNNER_USERNAME} || fail \"failed to install service\"\n"
        end

        s << "\n"
        s << <<-'BASH'
        if [ -e "/sys/fs/selinux" ];then
        	sudo chcon -R -h user_u:object_r:bin_t:s0 /home/runner/ || fail "failed to change selinux context"
        fi

        AGENT_ID=""
        BASH
        s << "\n"

        if use_jit_config
          s << <<-'BASH'
          if [ -f "$RUN_HOME/env.sh" ];then
          	pushd $RUN_HOME
          	source env.sh
          	popd
          fi
          sudo systemctl start $SVC_NAME || fail "failed to start service"
          BASH
          s << "\n"
        else
          s << "sendStatus \"starting service\"\n"
          s << "sudo ./svc.sh start || fail \"failed to start service\"\n\n"
          s << "set +e\n"
          s << "AGENT_ID=$(grep \"agentId\" \"$RUN_HOME\"/.runner | tr -d -c 0-9)\n"
          s << "if [ $? -ne 0 ];then\n"
          s << "\tfail \"failed to get agent ID\"\n"
          s << "fi\n"
          s << "set -e\n"
        end

        s << "systemInfo $AGENT_ID\n"
        s << "success \"runner successfully installed\" $AGENT_ID\n"
      end

      script
    end
  end
end
