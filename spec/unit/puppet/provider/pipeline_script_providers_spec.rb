# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

describe 'pipeline and script providers' do
  let(:context) { instance_double(Puppet::ResourceApi::BaseContext, debug: nil) }

  before { use_connections }

  describe 'opensearch_ingest_pipeline' do
    let(:provider) { load_provider('opensearch_ingest_pipeline').new }
    let(:name) { { name: 'p1', connection: 'default' } }
    let(:stored) { { 'description' => 'd', 'processors' => [{ 'set' => { 'field' => 'a', 'value' => 1 } }], 'version' => 3 } }

    before do
      stub_request(:get, api_url('_ingest/pipeline')).to_return(json('p1' => stored))
    end

    it 'lists pipelines with defaults for missing fields' do
      expect(provider.get(context)).to eq(
        [{ title: 'default/p1', ensure: 'present', name: 'p1', connection: 'default', description: 'd',
           processors: [{ 'set' => { 'field' => 'a', 'value' => 1 } }], on_failure: [], version: 3, }],
      )
    end

    it 'updates by sending the stored pipeline with the managed attributes replaced' do
      stub = stub_request(:put, api_url('_ingest/pipeline/p1')).with(body: stored.merge('description' => 'new')).to_return(json('acknowledged' => true))
      provider.get(context)
      provider.update(context, name, name.merge(description: 'new'))
      expect(stub).to have_been_requested
    end

    it 'requires processors to create a pipeline' do
      expect { provider.create(context, { name: 'p2', connection: 'default' }, { name: 'p2', description: 'x' }) }.to raise_error(Puppet::ResourceError, %r{processors})
    end
  end

  describe 'opensearch_search_pipeline' do
    let(:provider) { load_provider('opensearch_search_pipeline').new }

    it 'treats a 404 as no pipelines' do
      stub_request(:get, api_url('_search/pipeline')).to_return(status: 404, body: '{}')
      expect(provider.get(context)).to eq([])
    end

    it 'creates a pipeline with the managed attributes' do
      processors = [{ 'filter_query' => { 'query' => { 'match_all' => {} } } }]
      stub = stub_request(:put, api_url('_search/pipeline/sp')).with(body: { 'request_processors' => processors }).to_return(json('acknowledged' => true))
      provider.create(context, { name: 'sp', connection: 'default' }, { name: 'sp', request_processors: processors })
      expect(stub).to have_been_requested
    end
  end

  describe 'opensearch_stored_script' do
    let(:provider) { load_provider('opensearch_stored_script').new }
    let(:scripts_url) { api_url('_cluster/state/metadata?filter_path=metadata.stored_scripts') }
    let(:template) { { 'query' => { 'term' => { 'host' => '{{host}}' } } } }

    before do
      stub_request(:get, scripts_url).to_return(
        json('metadata' => { 'stored_scripts' => {
               's1' => { 'lang' => 'painless', 'source' => 'params.m * 2' },
               't1' => { 'lang' => 'mustache', 'source' => JSON.generate(template), 'options' => { 'content_type' => 'application/json' } },
             } }),
      )
    end

    it 'lists scripts from the cluster state, with templates parsed' do
      expect(provider.get(context).map { |r| [r[:name], r[:source]] }).to eq([['s1', 'params.m * 2'], ['t1', template]])
    end

    it 'treats a template in JSON text and as a Hash alike' do
      text = provider.canonicalize(context, [{ lang: 'mustache', source: '{"query": {"term": {"host": "{{host}}"}}}' }]).first
      hash = provider.canonicalize(context, [{ lang: 'mustache', source: { query: { term: { host: '{{host}}' } } } }]).first
      expect(text[:source]).to eq(template)
      expect(hash[:source]).to eq(template)
    end

    it 'stores with the context in the path, so that OpenSearch compiles the script' do
      stub = stub_request(:put, api_url('_scripts/s2/score')).with(body: { 'script' => { 'lang' => 'painless', 'source' => '1' } }).to_return(json('acknowledged' => true))
      provider.create(context, { name: 's2', connection: 'default' }, { name: 's2', lang: 'painless', source: '1', context: 'score' })
      expect(stub).to have_been_requested
    end

    it 'keeps the stored language when only the source changes' do
      stub = stub_request(:put, api_url('_scripts/s1')).with(body: { 'script' => { 'lang' => 'painless', 'source' => 'params.m * 3' } }).to_return(json('acknowledged' => true))
      provider.get(context)
      provider.update(context, { name: 's1', connection: 'default' }, { name: 's1', source: 'params.m * 3' })
      expect(stub).to have_been_requested
    end
  end
end
