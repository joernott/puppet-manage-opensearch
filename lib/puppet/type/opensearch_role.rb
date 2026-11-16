# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_role',
  docs: <<~DOC,
    @summary Manages a role of the OpenSearch security plugin.

    Built-in (reserved, static or hidden) roles are not listed and cannot be
    changed. The order of permissions does not matter. The title is either the
    name or `connection/name`.

    @example
      opensearch_role { 'logs_reader':
        cluster_permissions => ['cluster_composite_ops_ro'],
        index_permissions   => [
          {
            index_patterns  => ['logs-*'],
            allowed_actions => ['read'],
            fls             => ['~secret_field'],
          },
        ],
        tenant_permissions  => [
          { tenant_patterns => ['logs'], allowed_actions => ['kibana_all_read'] },
        ],
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
      desc: 'Whether the role should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the role.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    cluster_permissions: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Cluster-wide actions and action groups.',
    },
    index_permissions: {
      type: <<~TYPE,
        Optional[Array[Struct[{
          index_patterns            => Array[String[1], 1],
          Optional[allowed_actions] => Array[String[1]],
          Optional[dls]             => String,
          Optional[fls]             => Array[String[1]],
          Optional[masked_fields]   => Array[String[1]],
        }]]]
      TYPE
      desc: 'Index permissions: index patterns with their actions, document-level security (dls), field-level security (fls) and masked fields.',
    },
    tenant_permissions: {
      type: <<~TYPE,
        Optional[Array[Struct[{
          tenant_patterns           => Array[String[1], 1],
          Optional[allowed_actions] => Array[String[1]],
        }]]]
      TYPE
      desc: 'OpenSearch Dashboards tenant permissions.',
    },
    description: {
      type: 'Optional[String]',
      desc: 'A description of the role.',
    },
  },
)
