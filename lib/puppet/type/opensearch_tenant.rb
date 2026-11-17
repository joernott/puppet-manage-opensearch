# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_tenant',
  docs: <<~DOC,
    @summary Manages an OpenSearch Dashboards tenant of the security plugin.

    Built-in (reserved, static or hidden) tenants such as `global_tenant` are
    not listed and cannot be changed. The title is either the name or
    `connection/name`.

    @example
      opensearch_tenant { 'operations':
        description => 'Dashboards of the operations team',
      }
  DOC
  features: ['canonicalize'],
  title_patterns: [
    {
      pattern: %r{\A(?<connection>[a-z0-9_]+)/(?<name>[^/]+)\z},
      desc: 'connection/name',
    },
    {
      pattern: %r{\A(?<name>.+)\z}m,
      desc: 'name (uses the connection "default")',
    },
  ],
  autorequire: {
    file: '/etc/puppetlabs/manage_opensearch/connections.yaml',
  },
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether the tenant should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the tenant.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    description: {
      type: 'Optional[String]',
      desc: 'A description of the tenant.',
    },
  },
)
