# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

describe 'security providers' do
  let(:context) { instance_double(Puppet::ResourceApi::BaseContext, debug: nil) }
  let(:name) { { name: 'r1', connection: 'default' } }

  before { use_connections }

  describe 'opensearch_role' do
    let(:provider) { load_provider('opensearch_role').new }
    let(:roles_url) { api_url('_plugins/_security/api/roles') }

    describe '#get' do
      before do
        stub_request(:get, roles_url).to_return(json(
                                                  'all_access' => { 'reserved' => true, 'cluster_permissions' => ['*'] },
                                                  'hidden_role' => { 'hidden' => true },
                                                  'r1' => {
                                                    'reserved' => false, 'hidden' => false, 'static' => false,
                                                    'cluster_permissions' => %w[b a],
                                                    'index_permissions' => [
                                                      { 'index_patterns' => ['z-*'], 'allowed_actions' => ['read'], 'fls' => [], 'masked_fields' => [] },
                                                      { 'index_patterns' => ['a-*'], 'allowed_actions' => %w[write read], 'dls' => '{}', 'fls' => [], 'masked_fields' => [] },
                                                    ],
                                                  },
                                                ))
      end

      it 'returns the canonical non-built-in roles' do
        expect(provider.get(context)).to eq(
          [{
            title: 'default/r1', ensure: 'present', name: 'r1', connection: 'default',
            cluster_permissions: %w[a b],
            index_permissions: [
              { 'index_patterns' => ['a-*'], 'allowed_actions' => %w[read write], 'fls' => [], 'masked_fields' => [], 'dls' => '{}' },
              { 'index_patterns' => ['z-*'], 'allowed_actions' => ['read'], 'fls' => [], 'masked_fields' => [] },
            ],
            tenant_permissions: [],
            description: '',
          }],
        )
      end
    end

    describe '#canonicalize' do
      it 'normalizes set attributes and leaves unset ones alone' do
        resource = { name: 'r1', index_permissions: [{ 'index_patterns' => ['x'], 'dls' => '' }], cluster_permissions: nil }
        expect(provider.canonicalize(context, [resource])).to eq(
          [{ name: 'r1', index_permissions: [{ 'index_patterns' => ['x'], 'allowed_actions' => [], 'fls' => [], 'masked_fields' => [] }], cluster_permissions: nil }],
        )
      end
    end

    it 'creates with PUT' do
      stub = stub_request(:put, "#{roles_url}/r1").with(body: { 'cluster_permissions' => ['a'] }).to_return(json('status' => 'CREATED'))
      provider.create(context, name, name.merge(ensure: 'present', cluster_permissions: ['a'], description: nil))
      expect(stub).to have_been_requested
    end

    it 'updates only the managed attributes with PATCH' do
      stub = stub_request(:patch, "#{roles_url}/r1")
             .with(body: [{ 'op' => 'add', 'path' => '/description', 'value' => 'd' }].to_json)
             .to_return(json('status' => 'OK'))
      provider.update(context, name, name.merge(ensure: 'present', description: 'd', cluster_permissions: nil))
      expect(stub).to have_been_requested
    end

    it 'deletes' do
      stub = stub_request(:delete, "#{roles_url}/r1").to_return(json('status' => 'OK'))
      provider.delete(context, name)
      expect(stub).to have_been_requested
    end

    it 'escapes names' do
      stub = stub_request(:delete, "#{roles_url}/a%20b").to_return(json('status' => 'OK'))
      provider.delete(context, name: 'a b', connection: 'default')
      expect(stub).to have_been_requested
    end
  end

  describe 'opensearch_internal_user' do
    let(:provider) { load_provider('opensearch_internal_user').new }
    let(:users_url) { api_url('_plugins/_security/api/internalusers') }
    let(:password) { Puppet::Pops::Types::PSensitiveType::Sensitive.new('secret') }

    it 'sends the password on create' do
      stub = stub_request(:put, "#{users_url}/r1").with(body: { 'backend_roles' => ['b'], 'password' => 'secret' }).to_return(json('status' => 'CREATED'))
      provider.create(context, name, name.merge(ensure: 'present', password: password, backend_roles: ['b']))
      expect(stub).to have_been_requested
    end

    it 'can create with a hash instead' do
      stub = stub_request(:put, "#{users_url}/r1").with(body: { 'hash' => '$2y$12$x' }).to_return(json('status' => 'CREATED'))
      provider.create(context, name, name.merge(ensure: 'present', password_hash: '$2y$12$x'))
      expect(stub).to have_been_requested
    end

    it 'refuses to create a user without password' do
      expect { provider.create(context, name, name.merge(ensure: 'present')) }.to raise_error(Puppet::ResourceError, %r{password or password_hash is required})
    end

    it 'never sends the password on update' do
      stub = stub_request(:patch, "#{users_url}/r1")
             .with(body: [{ 'op' => 'add', 'path' => '/attributes', 'value' => { 'level' => '3' } }].to_json)
             .to_return(json('status' => 'OK'))
      provider.update(context, name, name.merge(ensure: 'present', password: password, attributes: { 'level' => '3' }))
      expect(stub).to have_been_requested
    end

    it 'treats the password as always in sync' do
      expect(provider.insync?(context, name, :password, { password: nil }, { password: password })).to be(true)
      expect(provider.insync?(context, name, :backend_roles, {}, {})).to be_nil
    end

    it 'stores attribute values as strings' do
      expect(provider.canonicalize(context, [{ attributes: { 'level' => 3 } }])).to eq([{ attributes: { 'level' => '3' } }])
    end
  end

  describe 'opensearch_role_mapping and opensearch_action_group' do
    it 'use their endpoints' do
      stub_request(:get, api_url('_plugins/_security/api/rolesmapping')).to_return(json('r1' => { 'users' => ['u'] }))
      stub_request(:get, api_url('_plugins/_security/api/actiongroups')).to_return(json('g1' => { 'allowed_actions' => %w[b a], 'type' => 'index' }))
      mapping = load_provider('opensearch_role_mapping').new.get(context).first
      group = load_provider('opensearch_action_group').new.get(context).first
      expect(mapping).to include(name: 'r1', users: ['u'], backend_roles: [], hosts: [])
      expect(group).to include(name: 'g1', allowed_actions: %w[a b], type: 'index')
    end
  end
end
