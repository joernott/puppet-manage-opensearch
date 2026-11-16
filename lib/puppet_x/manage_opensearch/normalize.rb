# frozen_string_literal: true

require 'json'

module PuppetX
  module ManageOpensearch
    # Helpers that bring manifest values and API responses into one canonical
    # form, so that comparing them is meaningful.
    module Normalize
      module_function

      # Converts all hash keys to strings, recursively.
      def stringify(value)
        case value
        when Hash then value.to_h { |k, v| [k.to_s, stringify(v)] }
        when Array then value.map { |v| stringify(v) }
        when Symbol then value.to_s
        else value
        end
      end

      # A list whose order has no meaning: strings, without duplicates, sorted.
      def string_set(value)
        Array(value).map(&:to_s).uniq.sort
      end

      # Sorts a list of hashes into a stable order.
      def sort_hashes(list)
        list.sort_by { |item| JSON.generate(item) }
      end

      # Flattens index settings into `index.`-prefixed dotted keys with string
      # values, which is how OpenSearch treats them:
      # {'index' => {'number_of_shards' => 1}} and {'number_of_shards' => '1'}
      # both become {'index.number_of_shards' => '1'}.
      def index_settings(settings)
        flatten(stringify(settings || {})).to_h do |key, value|
          key = "index.#{key}" unless key.start_with?('index.')
          [key, value.is_a?(Array) ? value.map(&:to_s) : value.to_s]
        end
      end

      def flatten(hash, prefix = nil)
        hash.each_with_object({}) do |(key, value), result|
          full = prefix ? "#{prefix}.#{key}" : key.to_s
          if value.is_a?(Hash)
            result.merge!(flatten(value, full))
          else
            result[full] = value
          end
        end
      end

      # True if everything in `expected` is present in `actual` with the same
      # value. Hashes may contain extra keys in `actual` (defaults the server
      # added). Arrays must have the same length and match element by element.
      # Scalars are compared as strings, so 1 matches "1".
      def subset?(expected, actual)
        case expected
        when Hash
          actual.is_a?(Hash) && expected.all? { |k, v| actual.key?(k) && subset?(v, actual[k]) }
        when Array
          actual.is_a?(Array) && expected.size == actual.size &&
            expected.zip(actual).all? { |e, a| subset?(e, a) }
        when nil
          actual.nil?
        else
          !actual.is_a?(Hash) && !actual.is_a?(Array) && expected.to_s == actual.to_s
        end
      end

      # Unwraps Puppet's Sensitive values.
      def unwrap(value)
        value.respond_to?(:unwrap) ? value.unwrap : value
      end
    end
  end
end
