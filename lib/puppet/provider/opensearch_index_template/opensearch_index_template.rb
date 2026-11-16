# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/provider'

# Manages composable index templates through _index_template.
#
# The API only offers PUT, which replaces the whole template. Updates
# therefore send the current template with the managed attributes replaced.
class Puppet::Provider::OpensearchIndexTemplate::OpensearchIndexTemplate < PuppetX::ManageOpensearch::Provider
  def attribute_normalizers
    {
      index_patterns: :string_set,
      template: :template_body,
      composed_of: :string_list,
      priority: :integer,
      version: :integer,
      meta: :hash_value,
      data_stream: :data_stream,
    }
  end

  def fetch_all(_context, client)
    data = client.get_if_exists('_index_template') || {}
    (data['index_templates'] || []).map do |entry|
      raw = entry['index_template']
      attributes = fields.to_h { |attribute, field| [attribute, raw[field]] }
      attributes[:composed_of] ||= []
      [entry['name'], raw, attributes]
    end
  end

  def create(context, name, should)
    context.debug("Creating #{name.inspect}")
    client(name[:connection]).put(path(name), body({}, should))
  end

  def update(context, name, should)
    context.debug("Updating #{name.inspect}")
    client(name[:connection]).put(path(name), body(current_raw(name) || {}, should))
  end

  def delete(context, name)
    context.debug("Deleting #{name.inspect}")
    client(name[:connection]).delete(path(name))
  end

  private

  # Resource attribute => API field
  def fields
    {
      index_patterns: 'index_patterns', template: 'template', composed_of: 'composed_of',
      priority: 'priority', version: 'version', meta: '_meta', data_stream: 'data_stream',
    }
  end

  def path(name)
    "_index_template/#{path_segment(name[:name])}"
  end

  def body(current, should)
    result = current.dup
    managed_values(should).each { |attribute, value| result[fields[attribute.to_sym]] = value }
    result
  end

  def string_list(value)
    Array(value).map(&:to_s)
  end

  # Settings flattened to `index.*` strings; empty parts dropped.
  def template_body(value)
    value = PuppetX::ManageOpensearch::Normalize.stringify(value)
    result = {}
    result['settings'] = PuppetX::ManageOpensearch::Normalize.index_settings(value['settings']) unless value['settings'].nil?
    result['mappings'] = value['mappings'] unless value['mappings'].nil?
    result['aliases'] = value['aliases'] unless value['aliases'].nil?
    result.reject { |_, v| v.empty? }
  end

  # OpenSearch fills in the default timestamp field.
  def data_stream(value)
    value = PuppetX::ManageOpensearch::Normalize.stringify(value)
    { 'timestamp_field' => { 'name' => '@timestamp' } }.merge(value)
  end
end
