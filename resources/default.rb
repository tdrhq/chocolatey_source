#
# Cookbook:: chocolatey_source
# resource:: chocolatey_source
#
# Copyright:: 2018, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

resource_name :chocolatey_source

property :source_name, String, name_property: true
property :source, String
property :bypass_proxy, [TrueClass, FalseClass], default: false
property :priority, Integer, default: 0

load_current_value do
  require 'rexml/document'
  element = fetch_source_element(source_name)
  current_value_does_not_exist! if element.nil?

  source_name element['id']
  source element['value']
  bypass_proxy element['bypassProxy'] == 'true'
  priority element['priority'].to_i
end

# @param [String] id the source name
# @return [REXML::Attributes] finds the source element with the
def fetch_source_element(id)
  config_file = 'C:\ProgramData\chocolatey\config\chocolatey.config'
  raise "Could not find the Chocolatey config at #{config_file}!" unless ::File.exist?(config_file)

  config_contents = REXML::Document.new(::File.read(config_file))
  data = REXML::XPath.first(config_contents, "//sources/source[@id=\"#{id}\"]")
  data ? data.attributes : nil # REXML just returns nil if it can't find anything so avoid an undefined method error
end

action :add do
  raise "#{new_resource}: When adding a Chocolatey source you must pass the 'source' property!" unless new_resource.source

  converge_if_changed do
    shell_out!(choco_cmd('add'))
  end
end

action :remove do
  if current_resource
    converge_by("remove Chocolatey source '#{new_resource.source_name}'") do
      shell_out!(choco_cmd('remove'))
    end
  end
end

# action :enable do
#   shell_out!(choco_cmd('enable'))
# end
#
# action :disable do
#   shell_out!(choco_cmd('disable')) if current_resource
# end

action_class do
  # @param [String] action the name of the action to perform
  # @return [String] the choco source command string
  def choco_cmd(action)
    cmd = "C:\\ProgramData\\chocolatey\\bin\\choco source #{action} -n \"#{new_resource.source_name}\""
    if action == 'add'
      cmd << " -s #{new_resource.source} --priority=#{new_resource.priority}"
      cmd << ' --bypassproxy' if new_resource.bypass_proxy
    end
    cmd
  end
end
