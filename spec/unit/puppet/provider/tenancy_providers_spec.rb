# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

describe 'tenant and singleton providers' do
  let(:context) { instance_double(Puppet::ResourceApi::BaseContext, debug: nil, warning: nil) }

  before do
    allow(context).to receive(:updating).and_yield
    use_connections
  end

  describe 'opensearch_tenant' do
    let(:provider) { load_provider('opensearch_tenant').new }

    it 'lists tenants except the built-in ones' do
      stub_request(:get, api_url('_plugins/_security/api/tenants')).to_return(
        json('global_tenant' => { 'description' => 'Global tenant', 'reserved' => true }, 'ops' => { 'description' => 'd', 'reserved' => false }),
      )
      expect(provider.get(context)).to eq([{ title: 'default/ops', ensure: 'present', name: 'ops', connection: 'default', description: 'd' }])
    end

    it 'creates a tenant' do
      stub = stub_request(:put, api_url('_plugins/_security/api/tenants/ops')).with(body: { 'description' => 'd' }).to_return(json('status' => 'CREATED'))
      provider.create(context, { name: 'ops', connection: 'default' }, { name: 'ops', description: 'd' })
      expect(stub).to have_been_requested
    end
  end

  describe 'opensearch_tenancy_config' do
    let(:provider) { load_provider('opensearch_tenancy_config').new }
    let(:config_url) { api_url('_plugins/_security/api/tenancy/config') }

    before do
      stub_request(:get, config_url).to_return(
        json('default_tenant' => '', 'private_tenant_enabled' => true, 'multitenancy_enabled' => true,
             'sign_in_options' => %w[SAML BASIC], 'preferred_tenants' => %w[b a]),
      )
    end

    it 'reads one resource per connection, with an empty default tenant as unset' do
      expect(provider.get(context, ['default'])).to eq(
        [{ connection: 'default', multitenancy_enabled: true, private_tenant_enabled: true, default_tenant: nil,
           sign_in_options: %w[BASIC SAML], preferred_tenants: %w[b a], }],
      )
    end

    it 'lists all connections when names are empty' do
      expect(provider.get(context, []).map { |r| r[:connection] }).to eq(['default'])
    end

    it 'sends only the changed attributes' do
      stub = stub_request(:put, config_url).with(body: { 'default_tenant' => 'ops' }).to_return(json({}))
      is = provider.get(context, ['default']).first
      should = is.merge(default_tenant: 'ops', private_tenant_enabled: true, multitenancy_enabled: nil)
      provider.set(context, 'default' => { is: is, should: should })
      expect(stub).to have_been_requested
    end
  end

  describe 'opensearch_allowlist' do
    let(:provider) { load_provider('opensearch_allowlist').new }
    let(:allowlist_url) { api_url('_plugins/_security/api/allowlist') }

    it 'reads the allow list with sorted methods' do
      stub_request(:get, allowlist_url).to_return(json('config' => { 'enabled' => false, 'requests' => { '/_cat/nodes' => %w[PUT GET] } }))
      expect(provider.get(context, ['default'])).to eq([{ connection: 'default', enabled: false, requests: { '/_cat/nodes' => %w[GET PUT] } }])
    end

    it 'sends the complete allow list on update' do
      stub_request(:get, allowlist_url).to_return(json('config' => { 'enabled' => false, 'requests' => { '/_cat/nodes' => ['GET'] } }))
      stub = stub_request(:put, allowlist_url).with(body: { 'enabled' => true, 'requests' => { '/_cat/nodes' => ['GET'] } }).to_return(json({}))
      is = provider.get(context, ['default']).first
      provider.set(context, 'default' => { is: is, should: { connection: 'default', enabled: true } })
      expect(stub).to have_been_requested
    end

    it 'skips connections without access when listing' do
      stub_request(:get, allowlist_url).to_return(status: 403, body: '{"status":"FORBIDDEN","message":"Access denied"}')
      expect(provider.get(context, [])).to eq([])
      expect(context).to have_received(:warning).with(%r{Skipping connection default.*Access denied})
    end

    it 'fails for a connection of the catalog without access' do
      stub_request(:get, allowlist_url).to_return(status: 403, body: '{"status":"FORBIDDEN","message":"Access denied"}')
      expect { provider.get(context, ['default']) }.to raise_error(PuppetX::ManageOpensearch::ApiError, %r{Access denied})
    end
  end
end
