# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_internal_user',
  docs: <<~DOC,
    @summary Manages a user of the OpenSearch security plugin's internal user database.

    The password (or its bcrypt hash) is only used when the user is created.
    After that it is ignored: changing it in the manifest does not change the
    user, and a password changed in OpenSearch is not reset.

    Built-in (reserved, static or hidden) users are not listed and cannot be
    changed. The title is either the name or `connection/name`.

    @example
      opensearch_internal_user { 'logstash':
        password                  => Sensitive('initial-secret'),
        backend_roles             => ['logstash'],
        opendistro_security_roles => ['logs_writer'],
        attributes                => { 'team' => 'ops' },
      }
  DOC
  features: ['canonicalize', 'custom_insync'],
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
    opensearch_role: '$opendistro_security_roles',
  },
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether the user should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the user.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    password: {
      type: 'Optional[Sensitive[String[1]]]',
      desc: 'The initial password. Only used when the user is created, never compared afterwards.',
    },
    password_hash: {
      type: 'Optional[String[1]]',
      desc: 'The initial password as bcrypt hash, instead of `password`. Only used when the user is created.',
      behaviour: :parameter,
    },
    backend_roles: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Backend roles of the user.',
    },
    opendistro_security_roles: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Roles assigned to the user directly, without a role mapping.',
    },
    attributes: {
      type: 'Optional[Hash[String[1], Scalar]]',
      desc: 'Custom attributes, usable e.g. in document-level security queries. Values are stored as strings.',
    },
    description: {
      type: 'Optional[String]',
      desc: 'A description of the user.',
    },
  },
)
