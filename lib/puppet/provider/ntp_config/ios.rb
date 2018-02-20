require 'puppet/resource_api'
require 'puppet/resource_api/simple_provider'
require 'puppet/util/network_device/cisco_ios/device'
require 'puppet/utility'
require 'pry'

# NTP Config Puppet Provider for Cisco IOS devices
class Puppet::Provider::NtpConfig::NtpConfig < Puppet::ResourceApi::SimpleProvider
  def parse(output)
    new_instance_fields = []
    new_instance = Puppet::Utility.parse_resource(output, @commands_hash)
    new_instance[:name] = 'default'
    new_instance[:authenticate] = !new_instance[:authenticate].nil?
    trusted_keys = new_instance[:trusted_key]
    trusted_key_field = []
    if trusted_keys.nil?
      trusted_key_field = trusted_keys
    else
      trusted_keys.each do |trusted_key|
        trusted_key_field << trusted_key
      end
      trusted_key_field = trusted_key_field.sort_by(&:to_i)
      trusted_key_field = trusted_key_field.join(',')
    end
    new_instance[:trusted_key] = trusted_key_field

    new_instance.delete_if { |_k, v| v.nil? }

    new_instance_fields << new_instance
    new_instance_fields
  end

  def config_command(is, should)
    set_command = ''
    if !should[:authenticate].nil?
      set_command_auth = @commands_hash['default']['attributes']['authenticate']['default']['set_value']
      set_command_auth = set_command_auth.gsub(%r{<state>},
                                               (should[:authenticate]) ? '' : 'no ')
    else
      set_command_auth = ''
    end
    set_command << set_command_auth

    if should[:source_interface]
      set_command_source = @commands_hash['default']['attributes']['source_interface']['default']['set_value']
      set_command_source = set_command_source.gsub(%r{<source_interface>},
                                                   (should[:source_interface] == 'unset') ? '' : should[:source_interface])
      set_command_source = set_command_source.gsub(%r{<state>},
                                                   (should[:source_interface] == 'unset') ? 'no ' : '')
    else
      set_command_source = ''
    end
    set_command << set_command_source

    set_command_new_keys = ''

    should_keys = []
    unless should[:trusted_key].nil?
      should_keys = should[:trusted_key].split(',')
    end

    is_keys = []
    unless is[:trusted_key].nil?
      is_keys = is[:trusted_key].split(',')
    end

    new_keys =  should_keys - is_keys
    remove_keys = is_keys - should_keys

    new_keys.each do |new_key|
      set_new_key = @commands_hash['default']['attributes']['trusted_key']['default']['set_value']
      set_new_key = set_new_key.gsub(%r{<state>}, '')
      set_new_key = set_new_key.gsub(%r{<trusted_key>}, new_key)
      set_command_new_keys << set_new_key
    end

    remove_keys.each do |remove_key|
      set_remove_key = @commands_hash['default']['attributes']['trusted_key']['default']['set_value']
      set_remove_key = set_remove_key.gsub(%r{<state>}, 'no ')
      set_remove_key = set_remove_key.gsub(%r{<trusted_key>}, remove_key)
      set_command_new_keys << set_remove_key
    end
    set_command << set_command_new_keys
  end

  def initialize
    @commands_hash = Puppet::Utility.load_yaml(File.expand_path(__dir__) + '/command.yaml')
  end

  def get(_context)
    output = Puppet::Util::NetworkDevice::Cisco_ios::Device.run_command_enable_mode(@commands_hash['default']['get_values'])
    return [] if output.nil?
    parse(output)
  end

  def set(context, changes)
    changes.each do |name, change|
      is = change.key?(:is) ? change[:is] : (get(context) || []).find { |key| key[:id] == name }
      should = change[:should]

      context.updating(name) do
        update(context, name, is, should)
      end
    end
  end

  def update(_context, _name, is, should)
    Puppet::Util::NetworkDevice::Cisco_ios::Device.run_command_conf_t_mode(config_command(is, should))
  end

  def create(_context, _name, _should); end

  def delete(_context, _name); end
end