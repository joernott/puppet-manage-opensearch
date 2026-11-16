# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_action_group',
  docs: <<~DOC,
    @summary Manages an action group of the OpenSearch security plugin.

    Built-in (reserved, static or hidden) action groups are not listed and
    cannot be changed. The title is either the name or `connection/name`.

    @example
      opensearch_action_group { 'logs_read':
        allowed_actions => ['indices:data/read*', 'indices:admin/mappings/get'],
        type            => 'index',
        description     => 'Read access to log indices',
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
      desc: 'Whether the action group should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the action group.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    allowed_actions: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Actions and other action groups this group contains. The order does not matter.',
    },
    type: {
      type: 'Optional[Enum[cluster, index, kibana]]',
      desc: 'Whether the group contains cluster, index or Dashboards actions.',
    },
    description: {
      type: 'Optional[String]',
      desc: 'A description of the action group.',
    },
  },
)
