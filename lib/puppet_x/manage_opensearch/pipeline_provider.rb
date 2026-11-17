# frozen_string_literal: true

require_relative 'provider'

module PuppetX
  module ManageOpensearch
    # Base class for ingest and search pipelines. Both are stored as one JSON
    # document per ID; PUT replaces the whole document, so updates send the
    # current document with the managed attributes replaced.
    #
    # Subclasses implement base_path, attribute_normalizers and defaults
    # (the value of an attribute that the API leaves out).
    class PipelineProvider < Provider
      def fetch_all(_context, client)
        (client.get_if_exists(base_path) || {}).map do |id, raw|
          attributes = attribute_normalizers.keys.to_h { |attribute| [attribute, raw.fetch(attribute.to_s) { defaults[attribute] }] }
          [id, raw, attributes]
        end
      end

      def create(context, name, should)
        context.debug("Creating #{name.inspect}")
        client(name[:connection]).put(path(name), managed_values(should))
      end

      def update(context, name, should)
        context.debug("Updating #{name.inspect}")
        client(name[:connection]).put(path(name), (current_raw(name) || {}).merge(managed_values(should)))
      end

      def delete(context, name)
        context.debug("Deleting #{name.inspect}")
        client(name[:connection]).delete(path(name))
      end

      private

      def path(name)
        "#{base_path}/#{path_segment(name[:name])}"
      end
    end
  end
end
