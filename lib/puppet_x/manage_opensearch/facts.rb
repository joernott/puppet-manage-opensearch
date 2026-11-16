# frozen_string_literal: true

require_relative 'client'

module PuppetX
  module ManageOpensearch
    # Builds the structured fact `opensearch`.
    module Facts
      TIMEOUT = 5
      # Node settings may contain passwords (e.g. of PEM keys); they must not
      # end up in PuppetDB.
      SECRET_KEY = %r{password|secret|token|credential}i.freeze

      module_function

      # @return [Hash] {'cluster' => {...}}; parts that fail are left out
      def collect(client = Client.for('default', 'timeout' => TIMEOUT, 'retries' => 0))
        cluster = {
          'health' => fetch('health') { client.get('_cluster/health') },
          'state' => fetch('state') { state(client) },
          'nodes' => fetch('nodes') { node_names(client) },
          'node' => fetch('node') { local_node(client) },
        }.compact
        { 'cluster' => cluster }
      end

      # A brief overview of the cluster: names, ids and roles of the nodes.
      def state(client)
        root = client.get('/')
        state = client.get('_cluster/state/version,nodes,cluster_manager_node')
        roles = client.get('_nodes', 'filter_path' => 'nodes.*.roles')['nodes'] || {}
        nodes = (state['nodes'] || {}).to_h do |id, node|
          [id, { 'name' => node['name'], 'roles' => (roles.dig(id, 'roles') || []).sort }]
        end
        {
          'cluster_name' => state['cluster_name'],
          'cluster_uuid' => state['cluster_uuid'],
          'version' => root.dig('version', 'number'),
          'state_version' => state['version'],
          'cluster_manager_node' => state['cluster_manager_node'],
          'nodes' => nodes,
        }
      end

      def node_names(client)
        nodes = client.get('_nodes', 'filter_path' => 'nodes.*.name')['nodes'] || {}
        nodes.values.map { |node| node['name'] }.sort
      end

      # Node info of the node the connection points to, i.e. this host.
      def local_node(client)
        id, node = (client.get('_nodes/_local')['nodes'] || {}).first
        return nil unless id

        redact(node).merge('id' => id)
      end

      def redact(value)
        case value
        when Hash then value.reject { |k, _| k.to_s.match?(SECRET_KEY) }.transform_values { |v| redact(v) }
        when Array then value.map { |v| redact(v) }
        else value
        end
      end

      def fetch(part)
        yield
      rescue StandardError => e
        message = "opensearch fact: cannot read cluster #{part}: #{e.message}"
        defined?(Facter) ? Facter.warn(message) : warn(message)
        nil
      end
    end
  end
end
