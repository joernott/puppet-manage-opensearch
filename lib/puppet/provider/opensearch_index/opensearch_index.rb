# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/provider'

# Manages single indices through the index APIs.
#
# Only the indices of the catalog are fetched (feature simple_get_filter);
# listing fetches all indices that are not hidden and don't start with a dot.
class Puppet::Provider::OpensearchIndex::OpensearchIndex < PuppetX::ManageOpensearch::Provider
  def attribute_normalizers
    { state: :string, settings: :settings, mappings: :hash_value }
  end

  # Settings that OpenSearch sets itself; they are not shown.
  def internal_setting
    %r{\Aindex\.(uuid|creation_date|provided_name|version\.|verified_before_close|history\.uuid|resize\.|routing\.allocation\.initial_recovery\.)}
  end

  def fetch_all(context, client)
    fetch(context, client, nil)
  end

  # raw: the index as returned by GET, plus 'state'
  def fetch(_context, client, names)
    return [] if names && names.empty?

    data = if names.nil?
             client.get('*', 'expand_wildcards' => 'open,closed')
           else
             client.get(names.map { |n| path_segment(n) }.join(','), 'expand_wildcards' => 'all', 'ignore_unavailable' => 'true')
           end
    states = index_states(client, names)
    (data || {}).filter_map do |index, info|
      next if names.nil? && index.start_with?('.')

      state = (states[index] == 'close') ? 'closed' : 'open'
      [index, info.merge('state' => state), { state: state, settings: info['settings'] || {}, mappings: info['mappings'] || {} }]
    end
  end

  # settings and mappings are in sync when the manifest is a subset of the
  # index (OpenSearch adds defaults and other fields).
  # The Resource API expects nil for "use the default comparison".
  # rubocop:disable-next Style/ReturnNilInPredicateMethodDefinition
  def insync?(_context, _name, property_name, is_hash, should_hash)
    return nil unless %i[settings mappings].include?(property_name)
    return nil if is_hash.nil? || should_hash.nil? || should_hash[property_name].nil?

    PuppetX::ManageOpensearch::Normalize.subset?(should_hash[property_name], is_hash[property_name] || {})
  end

  def create(context, name, should)
    context.debug("Creating #{name.inspect}")
    body = {}
    body['settings'] = should[:settings] unless should[:settings].nil?
    body['mappings'] = PuppetX::ManageOpensearch::Normalize.stringify(should[:mappings]) unless should[:mappings].nil?
    client(name[:connection]).put(index_path(name), body)
    client(name[:connection]).post("#{index_path(name)}/_close", nil) if should[:state] == 'closed'
  end

  # Closes before and opens after changing settings, so that static
  # settings can be changed together with `state => closed`.
  def update(context, name, should)
    context.debug("Updating #{name.inspect}")
    current = current_raw(name) || {}
    api = client(name[:connection])
    path = index_path(name)
    api.post("#{path}/_close", nil) if should[:state] == 'closed' && current['state'] == 'open'

    changed = changed_settings(should[:settings], settings(current['settings'] || {}))
    api.put("#{path}/_settings", changed) unless changed.empty?
    mappings = should[:mappings]
    api.put("#{path}/_mapping", PuppetX::ManageOpensearch::Normalize.stringify(mappings)) unless mappings.nil? || PuppetX::ManageOpensearch::Normalize.subset?(mappings, current['mappings'] || {})

    api.post("#{path}/_open", nil) if should[:state] == 'open' && current['state'] == 'closed'
  end

  def delete(context, name)
    context.debug("Deleting #{name.inspect}")
    client(name[:connection]).delete(index_path(name))
  end

  private

  def index_path(name)
    path_segment(name[:name])
  end

  # {index => 'open' | 'close'} from the cluster state.
  def index_states(client, names)
    path = names.nil? ? '_cluster/state/metadata' : "_cluster/state/metadata/#{names.map { |n| path_segment(n) }.join(',')}"
    params = { 'filter_path' => 'metadata.indices.*.state', 'expand_wildcards' => 'all', 'ignore_unavailable' => 'true' }
    data = client.get(path, params) || {}
    (data.dig('metadata', 'indices') || {}).transform_values { |index| index['state'] }
  end

  def changed_settings(should, current)
    return {} if should.nil?

    should.reject { |key, value| PuppetX::ManageOpensearch::Normalize.subset?(value, current[key]) }
  end

  def settings(value)
    PuppetX::ManageOpensearch::Normalize.index_settings(value).reject { |key, _| key.match?(internal_setting) }
  end
end
