# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'
require_relative 'client'
require_relative 'normalize'

module PuppetX
  module ManageOpensearch
    # Base class of all opensearch_* providers.
    #
    # Subclasses implement attribute_normalizers, which returns a hash of
    # attribute name => normalizer (a Symbol naming a method of the provider,
    # or nil to keep the value), and fetch_all, create, update and delete.
    # They use methods rather than constants because Puppet may load provider
    # files more than once.
    class Provider < Puppet::ResourceApi::SimpleProvider
      # Fetches the resources of the connections that the catalog uses, or of
      # all connections when listing (`puppet resource`, purging).
      #
      # Types with the feature simple_get_filter get the names of the wanted
      # resources (an empty list when listing) and can fetch only those by
      # overriding `fetch`.
      def get(context, names = nil)
        listing = names.nil? || names.empty?
        @current = {} if listing || @current.nil?
        connections = if listing
                        Config.connections.keys
                      else
                        names.map { |n| connection_of(n) }.uniq
                      end
        connections.flat_map do |connection|
          wanted = if listing
                     nil
                   else
                     names.select { |n| connection_of(n) == connection }.map { |n| n.is_a?(Hash) ? n[:name] : n }
                   end
          fetch(context, client(connection), wanted).map do |name, raw, attributes|
            @current[[connection, name]] = raw
            # The Resource API checks that the title parses back to both
            # namevars, so it always contains the connection.
            canonicalize_resource(attributes.merge(title: "#{connection}/#{name}", ensure: 'present', name: name, connection: connection))
          end
        end
      end

      def canonicalize(_context, resources)
        resources.map { |resource| canonicalize_resource(resource) }
      end

      # Normalizes the managed attributes that are set. Unset (nil) attributes
      # stay nil, so they remain unmanaged.
      def canonicalize_resource(resource)
        result = resource.dup
        attribute_normalizers.each do |attribute, normalizer|
          next if result[attribute].nil?

          result[attribute] = normalizer ? send(normalizer, result[attribute]) : result[attribute]
        end
        result
      end

      # Fetches the resources of one connection: all of them, or only `names`
      # if given. The default fetches all and lets the Resource API pick.
      def fetch(context, client, _names)
        fetch_all(context, client)
      end

      private

      def connection_of(name)
        (name.is_a?(Hash) && name[:connection]) || 'default'
      end

      def client(connection)
        @clients ||= {}
        @clients[connection] ||= Client.for(connection)
      end

      # The raw API data of a resource as read by get.
      def current_raw(name)
        (@current || {})[[name[:connection], name[:name]]]
      end

      # The managed attributes of `should` that are set, with string keys.
      def managed_values(should)
        attribute_normalizers.keys.each_with_object({}) do |attribute, result|
          result[attribute.to_s] = Normalize.stringify(should[attribute]) unless should[attribute].nil?
        end
      end

      def path_segment(value)
        Client.escape(value)
      end

      # Normalizers
      def string_set(value)
        Normalize.string_set(value)
      end

      def string(value)
        value.to_s
      end

      def integer(value)
        Integer(value)
      end

      def hash_value(value)
        Normalize.stringify(value)
      end
    end
  end
end
