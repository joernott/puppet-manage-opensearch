# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/security_provider'

# Manages roles through _plugins/_security/api/roles.
class Puppet::Provider::OpensearchRole::OpensearchRole < PuppetX::ManageOpensearch::SecurityProvider
  def endpoint
    'roles'
  end

  def attribute_normalizers
    {
      cluster_permissions: :string_set,
      index_permissions: :index_permissions,
      tenant_permissions: :tenant_permissions,
      description: :string,
    }
  end

  private

  def index_permissions(list)
    permissions = Array(list).map do |permission|
      permission = PuppetX::ManageOpensearch::Normalize.stringify(permission)
      result = {
        'index_patterns' => string_set(permission['index_patterns']),
        'allowed_actions' => string_set(permission['allowed_actions']),
        'fls' => string_set(permission['fls']),
        'masked_fields' => string_set(permission['masked_fields']),
      }
      result['dls'] = permission['dls'] unless permission['dls'].to_s.empty?
      result
    end
    PuppetX::ManageOpensearch::Normalize.sort_hashes(permissions)
  end

  def tenant_permissions(list)
    permissions = Array(list).map do |permission|
      permission = PuppetX::ManageOpensearch::Normalize.stringify(permission)
      {
        'tenant_patterns' => string_set(permission['tenant_patterns']),
        'allowed_actions' => string_set(permission['allowed_actions']),
      }
    end
    PuppetX::ManageOpensearch::Normalize.sort_hashes(permissions)
  end
end
