# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/singleton_provider'

# Manages the allow list through _plugins/_security/api/allowlist. PUT needs
# the complete configuration, so updates send the current one with the
# managed attributes replaced.
class Puppet::Provider::OpensearchAllowlist::OpensearchAllowlist < PuppetX::ManageOpensearch::SingletonProvider
  def path
    '_plugins/_security/api/allowlist'
  end

  def attribute_normalizers
    {
      enabled: nil,
      requests: :requests,
    }
  end

  def read(client)
    (client.get(path) || {})['config'] || {}
  end

  def attributes_from(data)
    { enabled: data['enabled'], requests: data['requests'] || {} }
  end

  def write(client, current, values)
    body = { 'enabled' => current.fetch('enabled', false), 'requests' => current.fetch('requests', {}) }.merge(values)
    client.put(path, body)
  end

  private

  def requests(value)
    PuppetX::ManageOpensearch::Normalize.stringify(value).transform_values { |methods| PuppetX::ManageOpensearch::Normalize.string_set(methods) }
  end
end
