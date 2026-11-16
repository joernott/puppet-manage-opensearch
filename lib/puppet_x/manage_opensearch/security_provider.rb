# frozen_string_literal: true

require_relative 'provider'

module PuppetX
  module ManageOpensearch
    # Base class for objects of the security plugin's REST API at
    # _plugins/_security/api/<ENDPOINT>.
    #
    # Reserved, static and hidden objects (the built-in ones) are not
    # reported. They cannot be changed through the API anyway, and leaving them
    # out keeps `resources { ...: purge => true }` from trying to delete them.
    #
    # Updates use PATCH with the managed attributes only, so attributes that
    # the manifest doesn't set are left alone.
    class SecurityProvider < Provider
      BASE_PATH = '_plugins/_security/api'

      def fetch_all(_context, client)
        (client.get(collection_path) || {}).filter_map do |name, data|
          next if builtin?(data)

          [name, data, from_api(data)]
        end
      end

      def create(context, name, should)
        context.debug("Creating #{name.inspect}")
        client(name[:connection]).put(item_path(name[:name]), create_body(should))
      end

      def update(context, name, should)
        context.debug("Updating #{name.inspect}")
        operations = managed_values(should).map do |attribute, value|
          { 'op' => 'add', 'path' => "/#{attribute}", 'value' => value }
        end
        client(name[:connection]).patch(item_path(name[:name]), operations) unless operations.empty?
      end

      def delete(context, name)
        context.debug("Deleting #{name.inspect}")
        client(name[:connection]).delete(item_path(name[:name]))
      end

      private

      def collection_path
        "#{BASE_PATH}/#{endpoint}"
      end

      def item_path(name)
        "#{collection_path}/#{path_segment(name)}"
      end

      def builtin?(data)
        data.is_a?(Hash) && (data['reserved'] || data['static'] || data['hidden'])
      end

      # Resource attributes from the API data. Values the API leaves out get
      # the empty value of their kind, so that e.g. `users => []` is in sync
      # with a mapping that has no users.
      def from_api(data)
        attribute_normalizers.to_h do |attribute, normalizer|
          [attribute, data.fetch(attribute.to_s) { EMPTY[normalizer] }]
        end
      end

      EMPTY = {
        string_set: [], hash_value: {}, string_map: {}, string: '',
        index_permissions: [], tenant_permissions: [],
      }.freeze
      private_constant :EMPTY

      # The body of the PUT that creates the object.
      def create_body(should)
        managed_values(should)
      end
    end
  end
end
