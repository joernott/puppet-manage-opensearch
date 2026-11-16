# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_role_mapping',
  docs: <<~DOC,
    @summary Maps users, backend roles and hosts to a role of the OpenSearch security plugin.

    The name is the name of the role. A mapping autorequires the
    `opensearch_role` of the same name. The title is either the role name or
    `connection/role`.

    @example
      opensearch_role_mapping { 'logs_reader':
        backend_roles => ['ldap-logs-readers'],
        users         => ['alice'],
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
    opensearch_role: '$name',
  },
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether the role mapping should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the role mapping.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    backend_roles: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Backend roles (e.g. LDAP groups) that get the role.',
    },
    and_backend_roles: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Backend roles that a user must all have to get the role.',
    },
    hosts: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Hosts whose requests get the role.',
    },
    users: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Users that get the role.',
    },
    description: {
      type: 'Optional[String]',
      desc: 'A description of the mapping.',
    },
  },
)
