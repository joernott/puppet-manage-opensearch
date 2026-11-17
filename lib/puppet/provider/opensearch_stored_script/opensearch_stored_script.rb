# frozen_string_literal: true

require 'json'
require_relative '../../../puppet_x/manage_opensearch/provider'

# Manages stored scripts and search templates through _scripts.
#
# There is no API that lists stored scripts; they are read from the cluster
# state. Search templates are stored as JSON text, so a template given as a
# Hash is compared with the parsed text.
class Puppet::Provider::OpensearchStoredScript::OpensearchStoredScript < PuppetX::ManageOpensearch::Provider
  def attribute_normalizers
    { lang: :string, source: nil }
  end

  def fetch_all(_context, client)
    data = client.get('_cluster/state/metadata', 'filter_path' => 'metadata.stored_scripts') || {}
    (data.dig('metadata', 'stored_scripts') || {}).map do |id, script|
      [id, script, { lang: script['lang'], source: script['source'] }]
    end
  end

  # A mustache source in JSON text becomes a Hash, so that both forms and
  # the stored text compare equal.
  def canonicalize_resource(resource)
    result = super
    source = result[:source]
    if source.is_a?(Hash)
      result[:source] = PuppetX::ManageOpensearch::Normalize.stringify(source)
    elsif source.is_a?(String) && result[:lang] == 'mustache'
      result[:source] = parse_template(source)
    end
    result
  end

  def create(context, name, should)
    context.debug("Creating #{name.inspect}")
    raise Puppet::ResourceError, "#{name[:name]}: lang and source are required to create a stored script" if should[:lang].nil? || should[:source].nil?

    store(name, should, should[:lang], should[:source])
  end

  def update(context, name, should)
    context.debug("Updating #{name.inspect}")
    current = current_raw(name) || {}
    store(name, should, should[:lang] || current['lang'], should[:source] || current['source'])
  end

  def delete(context, name)
    context.debug("Deleting #{name.inspect}")
    client(name[:connection]).delete("_scripts/#{path_segment(name[:name])}")
  end

  private

  def store(name, should, lang, source)
    path = "_scripts/#{path_segment(name[:name])}"
    path += "/#{path_segment(should[:context])}" if should[:context]
    client(name[:connection]).put(path, 'script' => { 'lang' => lang, 'source' => source })
  end

  def parse_template(text)
    parsed = JSON.parse(text)
    parsed.is_a?(Hash) ? parsed : text
  rescue JSON::ParserError
    text
  end
end
