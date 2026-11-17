# frozen_string_literal: true

require_relative 'provider'

module PuppetX
  module ManageOpensearch
    # Base class for settings that exist exactly once per cluster, such as the
    # multi-tenancy configuration. The only namevar is the connection, there
    # is no `ensure`: the object can be changed but not created or deleted.
    #
    # Subclasses implement attribute_normalizers, read(client) returning the
    # API data, attributes_from(data) and write(client, current, values).
    class SingletonProvider < Provider
      # Uses the feature simple_get_filter: `names` are the connections of the
      # catalog's resources, or empty when listing.
      def get(context, names = nil)
        listing = names.nil? || names.empty?
        @current ||= {}
        connections = if listing
                        Config.connections.keys
                      else
                        names.map { |n| n.is_a?(Hash) ? n[:connection] : n }.uniq
                      end
        connections.filter_map do |connection|
          data = read_for_listing(context, connection, listing)
          next if data.nil?

          @current[connection] = data
          canonicalize_resource(attributes_from(data).merge(connection: connection))
        end
      end

      def set(context, changes)
        changes.each do |connection, change|
          should = change[:should] || {}
          is = change[:is] || {}
          values = managed_values(should).reject { |attribute, _| should[attribute.to_sym] == is[attribute.to_sym] }
          next if values.empty?

          context.updating(connection) do
            write(client(connection), @current[connection] || {}, values)
          end
        end
      end

      private

      # When listing, connections that may not read the object (e.g. the
      # allow list without the admin certificate) are skipped with a warning.
      def read_for_listing(context, connection, listing)
        read(client(connection))
      rescue ApiError => e
        raise unless listing && [401, 403].include?(e.status)

        context.warning("Skipping connection #{connection}: #{e.message}")
        nil
      end
    end
  end
end
