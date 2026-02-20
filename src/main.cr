require "./version"
require "./config"
require "./util/env"
require "./provider/create"
require "./provider/delete"
require "./provider/get"
require "./provider/list"
require "./provider/remove_all"
require "./provider/start"
require "./provider/stop"

# garm-provider-vultr: External provider for garm that manages GitHub Actions runners on Vultr.
#
# This executable is called by garm with GARM_COMMAND set to one of:
#   CreateInstance, DeleteInstance, GetInstance, ListInstances,
#   RemoveAllInstances, Start, Stop
#
# See: https://github.com/cloudbase/garm/blob/main/doc/external_provider.md

module GarmProviderVultr
  def self.run
    command = Env.command

    case command
    when "CreateInstance"
      Commands.create_instance
    when "DeleteInstance"
      Commands.delete_instance
    when "GetInstance"
      Commands.get_instance
    when "ListInstances"
      Commands.list_instances
    when "RemoveAllInstances"
      Commands.remove_all_instances
    when "Start"
      Commands.start_instance
    when "Stop"
      Commands.stop_instance
    else
      STDERR.puts "unknown GARM_COMMAND: #{command}"
      exit 1
    end
  rescue ex
    STDERR.puts "Error [#{ENV["GARM_COMMAND"]? || "unknown"}]: #{ex.message}"
    exit 1
  end
end

GarmProviderVultr.run
