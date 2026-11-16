# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/security_provider'

# Manages action groups through _plugins/_security/api/actiongroups.
class Puppet::Provider::OpensearchActionGroup::OpensearchActionGroup < PuppetX::ManageOpensearch::SecurityProvider
  def endpoint
    'actiongroups'
  end

  def attribute_normalizers
    {
      allowed_actions: :string_set,
      type: :string,
      description: :string,
    }
  end
end
