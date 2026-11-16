# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/provider'

# Manages ISM policies through _plugins/_ism/policies.
#
# Updates send the stored policy with the managed attributes replaced, using
# optimistic concurrency control (if_seq_no / if_primary_term).
class Puppet::Provider::OpensearchIsmPolicy::OpensearchIsmPolicy < PuppetX::ManageOpensearch::Provider
  def attribute_normalizers
    {
      description: :string,
      default_state: :string,
      states: :hash_value,
      ism_template: :hash_value,
      error_notification: :hash_value,
    }
  end

  def fetch_all(_context, client)
    policies = []
    loop do
      page = client.get('_plugins/_ism/policies', 'size' => 100, 'from' => policies.size)
      batch = page['policies'] || []
      policies.concat(batch)
      break if batch.empty? || policies.size >= page['total_policies'].to_i
    end
    policies.map do |entry|
      policy = entry['policy']
      attributes = attribute_normalizers.keys.to_h { |attribute| [attribute, policy[attribute.to_s]] }
      attributes[:description] ||= ''
      attributes[:ism_template] ||= []
      [entry['_id'], entry, attributes]
    end
  end

  # states, ism_template and error_notification are in sync when the manifest
  # is a subset of the stored policy (the server adds defaults).
  # The Resource API expects nil for "use the default comparison".
  # rubocop:disable-next Style/ReturnNilInPredicateMethodDefinition
  def insync?(_context, _name, property_name, is_hash, should_hash)
    return nil unless %i[states ism_template error_notification].include?(property_name)
    return nil if is_hash.nil? || should_hash.nil?

    PuppetX::ManageOpensearch::Normalize.subset?(should_hash[property_name], is_hash[property_name])
  end

  def create(context, name, should)
    context.debug("Creating #{name.inspect}")
    client(name[:connection]).put(path(name), 'policy' => managed_values(should))
  end

  def update(context, name, should)
    context.debug("Updating #{name.inspect}")
    current = current_raw(name)
    policy = current['policy'].reject { |field, _| %w[policy_id last_updated_time schema_version].include?(field) }
    policy['ism_template'] = strip_template_times(policy['ism_template'])
    policy = policy.merge(managed_values(should)).compact
    params = { 'if_seq_no' => current['_seq_no'], 'if_primary_term' => current['_primary_term'] }
    client(name[:connection]).put(path(name), { 'policy' => policy }, params)
  end

  def delete(context, name)
    context.debug("Deleting #{name.inspect}")
    client(name[:connection]).delete(path(name))
  end

  private

  def path(name)
    "_plugins/_ism/policies/#{path_segment(name[:name])}"
  end

  def strip_template_times(templates)
    return templates unless templates.is_a?(Array)

    templates.map { |template| template.reject { |field, _| field == 'last_updated_time' } }
  end
end
