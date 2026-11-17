# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/security_provider'

# Manages tenants through _plugins/_security/api/tenants.
class Puppet::Provider::OpensearchTenant::OpensearchTenant < PuppetX::ManageOpensearch::SecurityProvider
  def endpoint
    'tenants'
  end

  def attribute_normalizers
    {
      description: :string,
    }
  end
end
