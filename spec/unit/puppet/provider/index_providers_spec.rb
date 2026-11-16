# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

describe 'index providers' do
  let(:context) { instance_double(Puppet::ResourceApi::BaseContext, debug: nil) }

  before { use_connections }

  describe 'opensearch_index_template' do
    let(:provider) { load_provider('opensearch_index_template').new }
    let(:name) { { name: 't1', connection: 'default' } }
    let(:stored) do
      {
        'index_patterns' => ['logs-*'],
        'template' => { 'settings' => { 'index' => { 'number_of_shards' => '1' } }, 'aliases' => { 'logs' => {} } },
        'composed_of' => [], 'priority' => 10, '_meta' => { 'owner' => 'ops' },
      }
    end

    before do
      stub_request(:get, api_url('_index_template')).to_return(json('index_templates' => [{ 'name' => 't1', 'index_template' => stored }]))
    end

    it 'returns canonical templates' do
      expect(provider.get(context)).to eq(
        [{
          title: 'default/t1', ensure: 'present', name: 't1', connection: 'default',
          index_patterns: ['logs-*'],
          template: { 'settings' => { 'index.number_of_shards' => '1' }, 'aliases' => { 'logs' => {} } },
          composed_of: [], priority: 10, version: nil, meta: { 'owner' => 'ops' }, data_stream: nil,
        }],
      )
    end

    it 'canonicalizes manifest settings like the API output' do
      should = provider.canonicalize(context, [{ template: { 'settings' => { 'number_of_shards' => 1 }, 'aliases' => { 'logs' => {} } } }])
      expect(should.first[:template]).to eq(provider.get(context).first[:template])
    end

    it 'fills in the default data stream timestamp field' do
      expect(provider.canonicalize(context, [{ data_stream: {} }]).first[:data_stream]).to eq('timestamp_field' => { 'name' => '@timestamp' })
    end

    it 'updates by sending the stored template with the managed attributes replaced' do
      stub = stub_request(:put, api_url('_index_template/t1')).with(body: stored.merge('priority' => 20, '_meta' => { 'owner' => 'dev' })).to_return(json('acknowledged' => true))
      provider.get(context)
      provider.update(context, name, name.merge(ensure: 'present', priority: 20, meta: { 'owner' => 'dev' }, template: nil))
      expect(stub).to have_been_requested
    end

    it 'creates with only the managed attributes' do
      stub = stub_request(:put, api_url('_index_template/t2')).with(body: { 'index_patterns' => ['x-*'] }).to_return(json('acknowledged' => true))
      provider.create(context, { name: 't2', connection: 'default' }, { name: 't2', index_patterns: ['x-*'] })
      expect(stub).to have_been_requested
    end
  end

  describe 'opensearch_ism_policy' do
    let(:provider) { load_provider('opensearch_ism_policy').new }
    let(:name) { { name: 'p1', connection: 'default' } }
    let(:policies_url) { api_url('_plugins/_ism/policies') }
    let(:states) do
      [{ 'name' => 'hot', 'actions' => [{ 'retry' => { 'count' => 3 }, 'rollover' => { 'min_size' => '10gb', 'copy_alias' => false } }], 'transitions' => [] }]
    end

    def policy(id)
      {
        '_id' => id, '_seq_no' => 7, '_primary_term' => 2,
        'policy' => {
          'policy_id' => id, 'description' => 'd', 'last_updated_time' => 1, 'schema_version' => 31,
          'error_notification' => nil, 'default_state' => 'hot', 'states' => states,
          'ism_template' => [{ 'index_patterns' => ['logs-*'], 'priority' => 5, 'last_updated_time' => 1 }],
        },
      }
    end

    before do
      stub_request(:get, "#{policies_url}?from=0&size=100").to_return(json('policies' => [policy('p1')], 'total_policies' => 2))
      stub_request(:get, "#{policies_url}?from=1&size=100").to_return(json('policies' => [policy('p2')], 'total_policies' => 2))
    end

    it 'reads all pages' do
      expect(provider.get(context).map { |p| p[:name] }).to eq(%w[p1 p2])
    end

    it 'treats the manifest as subset of the stored policy' do
      is = provider.get(context).first
      expect(provider.insync?(context, name, :states, is, { states: [{ 'name' => 'hot', 'actions' => [{ 'rollover' => { 'min_size' => '10gb' } }], 'transitions' => [] }] })).to be(true)
      expect(provider.insync?(context, name, :states, is, { states: [{ 'name' => 'hot', 'actions' => [{ 'rollover' => { 'min_size' => '20gb' } }], 'transitions' => [] }] })).to be(false)
      expect(provider.insync?(context, name, :ism_template, is, { ism_template: [{ 'index_patterns' => ['logs-*'], 'priority' => 5 }] })).to be(true)
      expect(provider.insync?(context, name, :description, is, { description: 'd' })).to be_nil
    end

    it 'updates with sequence number checks, without server fields' do
      new_states = [{ 'name' => 'hot', 'actions' => [], 'transitions' => [] }]
      expected = {
        'policy' => {
          'description' => 'd', 'default_state' => 'hot', 'states' => new_states,
          'ism_template' => [{ 'index_patterns' => ['logs-*'], 'priority' => 5 }],
        },
      }
      stub = stub_request(:put, "#{policies_url}/p1?if_primary_term=2&if_seq_no=7").with(body: expected).to_return(json('_id' => 'p1'))
      provider.get(context)
      provider.update(context, name, name.merge(ensure: 'present', states: new_states, description: nil))
      expect(stub).to have_been_requested
    end

    it 'creates without sequence numbers' do
      stub = stub_request(:put, "#{policies_url}/p3").with(body: { 'policy' => { 'default_state' => 'hot', 'states' => states } }).to_return(json('_id' => 'p3'))
      provider.create(context, { name: 'p3', connection: 'default' }, { name: 'p3', default_state: 'hot', states: states })
      expect(stub).to have_been_requested
    end
  end
end
