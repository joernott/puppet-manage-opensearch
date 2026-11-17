# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

describe 'index and alias providers' do
  let(:context) { instance_double(Puppet::ResourceApi::BaseContext, debug: nil) }

  before { use_connections }

  describe 'opensearch_alias' do
    let(:provider) { load_provider('opensearch_alias').new }
    let(:name) { { name: 'al', connection: 'default' } }
    let(:filter) { { 'term' => { 'a' => 'x' } } }

    before do
      stub_request(:get, api_url('_alias')).to_return(
        json('i1' => { 'aliases' => { 'al' => { 'filter' => filter, 'is_write_index' => true }, '.internal' => {} } },
             'i2' => { 'aliases' => { 'al' => { 'filter' => filter } } },
             'i3' => { 'aliases' => {} }),
      )
    end

    def aliases_request(actions)
      stub_request(:post, api_url('_aliases')).with(body: { 'actions' => actions }).to_return(json('acknowledged' => true))
    end

    it 'lists aliases except those starting with a dot' do
      expect(provider.get(context)).to eq(
        [{ title: 'default/al', ensure: 'present', name: 'al', connection: 'default', indices: %w[i1 i2], write_index: 'i1',
           filter: filter, index_routing: nil, search_routing: nil, is_hidden: nil, }],
      )
    end

    it 'is in sync only when every index has the shared option' do
      provider.get(context)
      expect(provider.insync?(context, name, :filter, {}, { filter: filter })).to be(true)
      expect(provider.insync?(context, name, :is_hidden, {}, { is_hidden: false })).to be(true)
      expect(provider.insync?(context, name, :filter, {}, { filter: { 'term' => { 'a' => 'y' } } })).to be(false)
      expect(provider.insync?(context, name, :indices, {}, { indices: ['i1'] })).to be_nil
    end

    it 'moves the alias atomically and keeps the options of the remaining indices' do
      stub = aliases_request([
                               { 'remove' => { 'index' => 'i1', 'alias' => 'al' } },
                               { 'add' => { 'filter' => filter, 'index' => 'i2', 'alias' => 'al', 'is_write_index' => true } },
                               { 'add' => { 'filter' => filter, 'index' => 'i3', 'alias' => 'al', 'is_write_index' => false } },
                             ])
      provider.get(context)
      provider.update(context, name, name.merge(indices: %w[i2 i3], write_index: 'i2'))
      expect(stub).to have_been_requested
    end

    it 'rejects a write index that is not one of the indices' do
      provider.get(context)
      expect { provider.update(context, name, name.merge(indices: ['i2'], write_index: 'i1')) }.to raise_error(Puppet::ResourceError, %r{write_index i1})
    end

    it 'removes the alias from all its indices' do
      stub = aliases_request([{ 'remove' => { 'index' => 'i1', 'alias' => 'al' } }, { 'remove' => { 'index' => 'i2', 'alias' => 'al' } }])
      provider.get(context)
      provider.delete(context, name)
      expect(stub).to have_been_requested
    end
  end

  describe 'opensearch_index' do
    let(:provider) { load_provider('opensearch_index').new }
    let(:name) { { name: 'idx', connection: 'default' } }
    let(:index) do
      {
        'aliases' => {},
        'mappings' => { 'dynamic' => 'false', 'properties' => { 'a' => { 'type' => 'keyword' } } },
        'settings' => { 'index' => { 'number_of_shards' => '1', 'number_of_replicas' => '0', 'uuid' => 'u', 'creation_date' => '1', 'provided_name' => 'idx' } },
      }
    end
    let(:state_params) { 'expand_wildcards=all&filter_path=metadata.indices.*.state&ignore_unavailable=true' }

    before do
      stub_request(:get, api_url('idx?expand_wildcards=all&ignore_unavailable=true')).to_return(json('idx' => index))
      stub_request(:get, api_url("_cluster/state/metadata/idx?#{state_params}")).to_return(json('metadata' => { 'indices' => { 'idx' => { 'state' => 'open' } } }))
    end

    it 'fetches only the wanted indices, without internal settings' do
      expect(provider.get(context, [name])).to eq(
        [{ title: 'default/idx', ensure: 'present', name: 'idx', connection: 'default', state: 'open',
           settings: { 'index.number_of_shards' => '1', 'index.number_of_replicas' => '0' }, mappings: index['mappings'], }],
      )
    end

    it 'lists all indices except those starting with a dot' do
      stub_request(:get, api_url('*?expand_wildcards=open,closed')).to_return(json('idx' => index, '.ds-x-000001' => index))
      stub_request(:get, api_url("_cluster/state/metadata?#{state_params}")).to_return(json('metadata' => { 'indices' => { 'idx' => { 'state' => 'close' } } }))
      expect(provider.get(context, []).map { |r| [r[:name], r[:state]] }).to eq([%w[idx closed]])
    end

    it 'compares settings and mappings as subsets' do
      is = provider.get(context, [name]).first
      should = provider.canonicalize(context, [{ settings: { 'number_of_replicas' => 0 }, mappings: { 'dynamic' => false } }]).first
      expect(provider.insync?(context, name, :settings, is, should)).to be(true)
      expect(provider.insync?(context, name, :mappings, is, should)).to be(true)
      should = provider.canonicalize(context, [{ settings: { 'index' => { 'number_of_replicas' => 1 } } }]).first
      expect(provider.insync?(context, name, :settings, is, should)).to be(false)
    end

    it 'creates the index and closes it if wanted' do
      create = stub_request(:put, api_url('new')).with(body: { 'settings' => { 'index.number_of_shards' => '1' } }).to_return(json('acknowledged' => true))
      close = stub_request(:post, api_url('new/_close')).to_return(json('acknowledged' => true))
      should = provider.canonicalize(context, [{ name: 'new', settings: { 'number_of_shards' => 1 }, state: 'closed' }]).first
      provider.create(context, { name: 'new', connection: 'default' }, should)
      expect(create).to have_been_requested
      expect(close).to have_been_requested
    end

    it 'closes the index before changing static settings and sends only changed settings' do
      close = stub_request(:post, api_url('idx/_close')).to_return(json('acknowledged' => true))
      settings = stub_request(:put, api_url('idx/_settings')).with(body: { 'index.codec' => 'best_compression' }).to_return(json('acknowledged' => true))
      provider.get(context, [name])
      should = provider.canonicalize(context, [name.merge(state: 'closed', settings: { 'codec' => 'best_compression', 'number_of_shards' => 1 })]).first
      provider.update(context, name, should)
      expect(close).to have_been_requested
      expect(settings).to have_been_requested
    end

    it 'adds new mapping fields' do
      mapping = stub_request(:put, api_url('idx/_mapping')).with(body: { 'properties' => { 'b' => { 'type' => 'text' } } }).to_return(json('acknowledged' => true))
      provider.get(context, [name])
      provider.update(context, name, name.merge(mappings: { 'properties' => { 'b' => { 'type' => 'text' } } }))
      expect(mapping).to have_been_requested
    end
  end
end
