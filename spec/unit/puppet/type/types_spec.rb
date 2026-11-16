# frozen_string_literal: true

require 'spec_helper'
require 'puppet/resource_api'

types = %w[
  opensearch_action_group opensearch_role opensearch_role_mapping
  opensearch_internal_user opensearch_index_template opensearch_ism_policy
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

describe 'opensearch_role validation' do
  it 'rejects index permissions without index patterns' do
    expect do
      Puppet::Type.type(:opensearch_role).new(title: 'r', index_permissions: [{ 'allowed_actions' => ['read'] }])
    end.to raise_error(Puppet::ResourceError, %r{index_patterns})
  end
end
