# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/singleton_provider'

# Manages the multi-tenancy configuration through
# _plugins/_security/api/tenancy/config. PUT accepts a partial
# configuration, so only the changed attributes are sent.
class Puppet::Provider::OpensearchTenancyConfig::OpensearchTenancyConfig < PuppetX::ManageOpensearch::SingletonProvider
  def path
    '_plugins/_security/api/tenancy/config'
  end

  def attribute_normalizers
    {
      multitenancy_enabled: nil,
      private_tenant_enabled: nil,
      default_tenant: :string,
      sign_in_options: :string_set,
      preferred_tenants: :string_list,
    }
  end

  def read(client)
    client.get(path) || {}
  end

  def attributes_from(data)
    attributes = attribute_normalizers.keys.to_h { |attribute| [attribute, data[attribute.to_s]] }
    # An empty default tenant means "not set".
    attributes[:default_tenant] = nil if attributes[:default_tenant] == ''
    attributes
  end

  def write(client, _current, values)
    client.put(path, values)
  end

  private

  def string_list(value)
    Array(value).map(&:to_s)
  end
end
