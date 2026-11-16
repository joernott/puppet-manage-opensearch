# frozen_string_literal: true

require 'voxpupuli/test/spec_helper'
require 'webmock/rspec'
require 'tmpdir'
require 'yaml'

# Unit tests never talk to a real cluster.
WebMock.disable_net_connect!

# Helpers for the provider and library tests.
module ManageOpensearchSpecHelpers
  URL = 'https://os.example.com:9200'

  # Points the library at a temporary connection file for the example.
  def use_connections(connections = { 'default' => { 'url' => URL, 'username' => 'admin', 'password' => 'pw', 'retries' => 0 } })
    dir = Dir.mktmpdir
    path = File.join(dir, 'connections.yaml')
    File.write(path, { 'connections' => connections }.to_yaml)
    ENV['MANAGE_OPENSEARCH_CONFIG'] = path
    path
  end

  # Loads a provider class the way the Resource API does.
  def load_provider(type)
    module_name = type.split('_').map(&:capitalize).join
    Puppet::Provider.const_set(module_name, Module.new) unless Puppet::Provider.const_defined?(module_name, false)
    require "puppet/provider/#{type}/#{type}"
    Puppet::Provider.const_get(module_name).const_get(module_name)
  end

  def api_url(path)
    "#{URL}/#{path}"
  end

  def json(body)
    { status: 200, body: JSON.generate(body), headers: { 'Content-Type' => 'application/json' } }
  end
end

RSpec.configure do |config|
  config.include ManageOpensearchSpecHelpers
  config.after { ENV.delete('MANAGE_OPENSEARCH_CONFIG') }
end
