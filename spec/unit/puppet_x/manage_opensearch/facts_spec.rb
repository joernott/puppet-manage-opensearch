# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/manage_opensearch/facts'

describe PuppetX::ManageOpensearch::Facts do
  let(:client) { PuppetX::ManageOpensearch::Client.new('url' => ManageOpensearchSpecHelpers::URL, 'retries' => 0) }
  let(:fact) { described_class.collect(client) }
  let(:cluster_state) do
    {
      'cluster_name' => 'c1', 'cluster_uuid' => 'u1', 'version' => 42, 'state_uuid' => 's',
      'cluster_manager_node' => 'id1',
      'nodes' => { 'id1' => { 'name' => 'n1', 'transport_address' => '10.0.0.1:9300' }, 'id2' => { 'name' => 'n2' } },
    }
  end
  let(:roles) { { 'nodes' => { 'id1' => { 'roles' => %w[data cluster_manager] }, 'id2' => { 'roles' => ['ingest'] } } } }
  let(:local_node) do
    ssl = { 'pemkey_password' => 'secret', 'pemcert_filepath' => 'c.pem' }
    { 'nodes' => { 'id1' => { 'name' => 'n1', 'settings' => { 'plugins' => { 'security' => { 'ssl' => ssl } } } } } }
  end

  before do
    stub_request(:get, api_url('_cluster/health')).to_return(json('cluster_name' => 'c1', 'status' => 'green'))
    stub_request(:get, api_url('')).to_return(json('version' => { 'number' => '3.9.0' }))
    stub_request(:get, api_url('_cluster/state/version,nodes,cluster_manager_node')).to_return(json(cluster_state))
    stub_request(:get, api_url('_nodes?filter_path=nodes.*.roles')).to_return(json(roles))
    stub_request(:get, api_url('_nodes?filter_path=nodes.*.name')).to_return(json('nodes' => { 'id2' => { 'name' => 'n2' }, 'id1' => { 'name' => 'n1' } }))
    stub_request(:get, api_url('_nodes/_local')).to_return(json(local_node))
  end

  it 'reports the cluster health' do
    expect(fact['cluster']['health']).to eq('cluster_name' => 'c1', 'status' => 'green')
  end

  it 'reports a brief cluster state' do
    expect(fact['cluster']['state']).to eq(
      'cluster_name' => 'c1', 'cluster_uuid' => 'u1', 'version' => '3.9.0', 'state_version' => 42,
      'cluster_manager_node' => 'id1',
      'nodes' => {
        'id1' => { 'name' => 'n1', 'roles' => %w[cluster_manager data] },
        'id2' => { 'name' => 'n2', 'roles' => ['ingest'] },
      }
    )
  end

  it 'reports the sorted node names' do
    expect(fact['cluster']['nodes']).to eq(%w[n1 n2])
  end

  it 'reports the local node without secrets' do
    expect(fact['cluster']['node']).to eq(
      'id' => 'id1', 'name' => 'n1',
      'settings' => { 'plugins' => { 'security' => { 'ssl' => { 'pemcert_filepath' => 'c.pem' } } } }
    )
  end

  it 'reports plugins and modules only with name and version' do
    component = {
      'name' => 'opensearch-security', 'version' => '3.9.0.0', 'opensearch_version' => '3.9.0',
      'description' => 'Provide access control related features for OpenSearch',
      'classname' => 'org.opensearch.security.OpenSearchSecurityPlugin', 'has_native_controller' => false,
    }
    local_node['nodes']['id1']['plugins'] = [component]
    local_node['nodes']['id1']['modules'] = [component.merge('name' => 'aggs-matrix-stats')]
    stub_request(:get, api_url('_nodes/_local')).to_return(json(local_node))
    expect(fact['cluster']['node']).to include(
      'plugins' => [{ 'name' => 'opensearch-security', 'version' => '3.9.0.0' }],
      'modules' => [{ 'name' => 'aggs-matrix-stats', 'version' => '3.9.0.0' }],
    )
  end

  it 'leaves out parts that fail, with a warning' do
    stub_request(:get, api_url('_cluster/health')).to_return(status: 500, body: 'boom')
    allow(Facter).to receive(:warn)
    expect(fact['cluster']).not_to have_key('health')
    expect(fact['cluster']).to have_key('state')
    expect(Facter).to have_received(:warn).with(%r{cannot read cluster health})
  end
end
