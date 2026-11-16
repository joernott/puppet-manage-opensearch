# frozen_string_literal: true

require_relative '../../../puppet_x/manage_opensearch/provider'

# Manages data streams through _data_stream. A data stream has no settings of
# its own: it is created from the matching index template, so there is
# nothing to update.
class Puppet::Provider::OpensearchDataStream::OpensearchDataStream < PuppetX::ManageOpensearch::Provider
  def attribute_normalizers
    {}
  end

  def fetch_all(_context, client)
    data = client.get_if_exists('_data_stream') || {}
    (data['data_streams'] || []).reject { |stream| stream['name'].start_with?('.') }.map do |stream|
      [stream['name'], stream, { template: stream['template'], generation: stream['generation'] }]
    end
  end

  def create(context, name, _should)
    context.debug("Creating #{name.inspect}")
    client(name[:connection]).put(path(name), nil)
  end

  # Only read-only attributes could differ.
  def update(context, name, _should)
    context.debug("Nothing to update for #{name.inspect}")
  end

  def delete(context, name)
    context.debug("Deleting #{name.inspect}")
    client(name[:connection]).delete(path(name))
  end

  private

  def path(name)
    "_data_stream/#{path_segment(name[:name])}"
  end
end
