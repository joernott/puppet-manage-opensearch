# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/provider'

# Manages index aliases through _alias and _aliases.
#
# An alias has its own options on each index. The options of the resource
# apply to all its indices: they are in sync when every index has them.
# Adding an alias to an index again replaces all its options there, so
# updates always send the complete options of every index.
class Puppet::Provider::OpensearchAlias::OpensearchAlias < PuppetX::ManageOpensearch::Provider
  def attribute_normalizers
    {
      indices: :string_set,
      write_index: :string,
      filter: :hash_value,
      index_routing: :string,
      search_routing: :string,
      is_hidden: nil,
    }
  end

  # The options that are the same for all indices of an alias.
  def shared_options
    %w[filter index_routing search_routing is_hidden]
  end

  # raw: {index => options}
  def fetch_all(_context, client)
    aliases = {}
    (client.get('_alias') || {}).each do |index, data|
      (data['aliases'] || {}).each do |alias_name, options|
        next if alias_name.start_with?('.')

        (aliases[alias_name] ||= {})[index] = options || {}
      end
    end
    aliases.map do |alias_name, indices|
      first = indices[indices.keys.min]
      attributes = {
        indices: indices.keys,
        write_index: indices.find { |_, options| options['is_write_index'] }&.first,
      }
      shared_options.each { |option| attributes[option.to_sym] = first[option] }
      [alias_name, indices, attributes]
    end
  end

  # The shared options are in sync when every index has the wanted value.
  # The Resource API expects nil for "use the default comparison".
  # rubocop:disable-next Style/ReturnNilInPredicateMethodDefinition
  def insync?(_context, name, property_name, _is_hash, should_hash)
    return nil unless shared_options.include?(property_name.to_s)

    wanted = should_hash[property_name]
    return nil if wanted.nil?

    indices = current_raw(name) || {}
    !indices.empty? && indices.values.all? { |options| same?(options[property_name.to_s], wanted, property_name) }
  end

  def create(context, name, should)
    context.debug("Creating #{name.inspect}")
    raise Puppet::ResourceError, "#{name[:name]}: indices are required to create an alias" if should[:indices].nil?

    apply(name, {}, should)
  end

  def update(context, name, should)
    context.debug("Updating #{name.inspect}")
    apply(name, current_raw(name) || {}, should)
  end

  def delete(context, name)
    context.debug("Deleting #{name.inspect}")
    actions = (current_raw(name) || {}).keys.map { |index| { 'remove' => { 'index' => index, 'alias' => name[:name] } } }
    client(name[:connection]).post('_aliases', 'actions' => actions) unless actions.empty?
  end

  private

  def apply(name, current, should)
    indices = should[:indices] || current.keys
    write_index = should[:write_index]
    raise Puppet::ResourceError, "#{name[:name]}: write_index #{write_index} is not one of the indices #{indices.join(', ')}" if write_index && !indices.include?(write_index)

    actions = (current.keys - indices).map { |index| { 'remove' => { 'index' => index, 'alias' => name[:name] } } }
    indices.each do |index|
      options = (current[index] || first_options(current)).slice(*shared_options, 'is_write_index')
      shared_options.each { |option| options[option] = should[option.to_sym] unless should[option.to_sym].nil? }
      options['is_write_index'] = (index == write_index) if write_index
      options.delete('is_write_index') unless current.key?(index) || write_index
      actions << { 'add' => options.merge('index' => index, 'alias' => name[:name]) }
    end
    client(name[:connection]).post('_aliases', 'actions' => actions)
  end

  # New indices get the shared options of the existing ones.
  def first_options(current)
    return {} if current.empty?

    current[current.keys.min].slice(*shared_options)
  end

  # An alias without is_hidden is not hidden.
  def same?(actual, wanted, property_name)
    actual = false if actual.nil? && property_name.to_sym == :is_hidden
    actual == wanted
  end
end
