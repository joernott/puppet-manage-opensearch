# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/security_provider'

# Manages role mappings through _plugins/_security/api/rolesmapping.
class Puppet::Provider::OpensearchRoleMapping::OpensearchRoleMapping < PuppetX::ManageOpensearch::SecurityProvider
  def endpoint
    'rolesmapping'
  end

  def attribute_normalizers
    {
      backend_roles: :string_set,
      and_backend_roles: :string_set,
      hosts: :string_set,
      users: :string_set,
      description: :string,
    }
  end
end
