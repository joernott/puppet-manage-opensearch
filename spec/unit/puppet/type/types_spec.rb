# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

types = %w[
  opensearch_action_group opensearch_role opensearch_role_mapping
  opensearch_internal_user opensearch_index_template opensearch_ism_policy
  opensearch_data_stream opensearch_tenant opensearch_ingest_pipeline
  opensearch_search_pipeline opensearch_stored_script opensearch_alias opensearch_index
]

types.each do |type_name|
  describe type_name do
    let(:type) { Puppet::Type.type(type_name.to_sym) }

    it 'is registered' do
      expect(type).not_to be_nil
    end

    it 'uses the connection "default" for plain titles' do
      resource = type.new(title: 'x')
      expect(resource[:name]).to eq('x')
      expect(resource[:connection]).to eq('default')
    end

    it 'accepts connection/name titles' do
      resource = type.new(title: 'other/x')
      expect(resource[:name]).to eq('x')
      expect(resource[:connection]).to eq('other')
    end
  end
end

describe 'type validation' do
  it 'rejects role index permissions without index patterns' do
    expect do
      Puppet::Type.type(:opensearch_role).new(title: 'r', index_permissions: [{ 'allowed_actions' => ['read'] }])
    end.to raise_error(Puppet::ResourceError, %r{index_patterns})
  end

  it 'rejects index names with upper case letters or wildcards' do
    %w[Logs logs-*].each do |title|
      expect { Puppet::Type.type(:opensearch_index).new(title: title) }.to raise_error(Puppet::ResourceError)
    end
  end

  %w[opensearch_tenancy_config opensearch_allowlist].each do |type_name|
    it "uses the title of #{type_name} as the connection" do
      resource = Puppet::Type.type(type_name.to_sym).new(title: 'superadmin')
      expect(resource[:connection]).to eq('superadmin')
    end
  end
end
