# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/security_provider'

# Manages internal users through _plugins/_security/api/internalusers.
#
# The password is only sent when the user is created. Updates use PATCH
# without the password, so the stored hash stays as it is.
class Puppet::Provider::OpensearchInternalUser::OpensearchInternalUser < PuppetX::ManageOpensearch::SecurityProvider
  def endpoint
    'internalusers'
  end

  def attribute_normalizers
    {
      backend_roles: :string_set,
      opendistro_security_roles: :string_set,
      attributes: :string_map,
      description: :string,
    }
  end

  # The password is only set on creation, so it is always in sync. Everything
  # else uses Puppet's normal comparison.
  # The Resource API expects nil for "use the default comparison".
  # rubocop:disable-next Style/ReturnNilInPredicateMethodDefinition
  def insync?(_context, _name, property_name, _is_hash, _should_hash)
    return true if property_name == :password

    nil
  end

  private

  def create_body(should)
    body = managed_values(should)
    password = PuppetX::ManageOpensearch::Normalize.unwrap(should[:password])
    if password
      body['password'] = password
    elsif should[:password_hash]
      body['hash'] = should[:password_hash]
    else
      raise Puppet::ResourceError, "opensearch_internal_user[#{should[:name]}]: password or password_hash is required to create the user"
    end
    body
  end

  def string_map(value)
    value.to_h { |k, v| [k.to_s, v.to_s] }
  end
end
