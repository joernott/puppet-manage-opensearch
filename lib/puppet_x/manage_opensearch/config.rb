# frozen_string_literal: true

require 'yaml'

module PuppetX
  module ManageOpensearch
    # Raised when the connection file is missing or invalid.
    class ConfigError < StandardError; end

    # Reads the connection file written by the class manage_opensearch.
    #
    # The environment variable MANAGE_OPENSEARCH_CONFIG overrides the path,
    # which the tests use.
    module Config
      DEFAULT_PATH = '/etc/puppetlabs/manage_opensearch/connections.yaml'

      def self.path
        ENV.fetch('MANAGE_OPENSEARCH_CONFIG', DEFAULT_PATH)
      end

      def self.exist?
        File.exist?(path)
      end

      # @return [Hash{String => Hash}] connection settings by name
      def self.connections
        data = YAML.safe_load(File.read(path)) || {}
        connections = data['connections'] if data.is_a?(Hash)
        raise ConfigError, "#{path} has no 'connections' section" unless connections.is_a?(Hash)

        connections
      rescue Errno::ENOENT
        raise ConfigError, "#{path} not found, include the class manage_opensearch"
      rescue Psych::Exception => e
        raise ConfigError, "#{path} is not valid YAML: #{e.message}"
      end

      # @return [Hash] the settings of one connection
      def self.connection(name)
        connections.fetch(name) do
          raise ConfigError, "connection '#{name}' is not defined in #{path}"
        end
      end
    end
  end
end
