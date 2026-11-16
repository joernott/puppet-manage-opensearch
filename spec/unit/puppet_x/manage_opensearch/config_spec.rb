# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/manage_opensearch/config'

describe PuppetX::ManageOpensearch::Config do
  it 'uses the default path' do
    expect(described_class.path).to eq('/etc/puppetlabs/manage_opensearch/connections.yaml')
  end

  it 'reads the connections' do
    use_connections('default' => { 'url' => 'https://a:9200' })
    expect(described_class.exist?).to be(true)
    expect(described_class.connection('default')).to eq('url' => 'https://a:9200')
  end

  it 'explains a missing file' do
    ENV['MANAGE_OPENSEARCH_CONFIG'] = '/nonexistent/connections.yaml'
    expect(described_class.exist?).to be(false)
    expect { described_class.connections }.to raise_error(PuppetX::ManageOpensearch::ConfigError, %r{include the class manage_opensearch})
  end

  it 'rejects a file without connections' do
    path = use_connections
    File.write(path, "--- {}\n")
    expect { described_class.connections }.to raise_error(PuppetX::ManageOpensearch::ConfigError, %r{no 'connections' section})
  end
end
