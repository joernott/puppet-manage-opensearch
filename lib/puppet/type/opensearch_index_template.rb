# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_index_template',
  docs: <<~DOC,
    @summary Manages a composable index template (`_index_template`).

    Index settings may be nested or dotted, with or without the `index.`
    prefix, and with numbers or strings: `{ 'number_of_shards' => 1 }` and
    `{ 'index' => { 'number_of_shards' => '1' } }` are the same. Attributes
    that are not set are kept as they are in the cluster. The title is either
    the name or `connection/name`.

    @example
      opensearch_index_template { 'logs':
        index_patterns => ['logs-*'],
        priority       => 100,
        template       => {
          'settings' => { 'number_of_shards' => 1, 'refresh_interval' => '5s' },
          'mappings' => { 'properties' => { 'message' => { 'type' => 'text' } } },
          'aliases'  => { 'logs' => {} },
        },
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
      desc: 'Whether the index template should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the index template.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    index_patterns: {
      type: 'Optional[Array[String[1], 1]]',
      desc: 'Index name patterns the template applies to. Required when creating the template.',
    },
    template: {
      type: 'Optional[Struct[{Optional[settings] => Hash, Optional[mappings] => Hash, Optional[aliases] => Hash}]]',
      desc: 'Settings, mappings and aliases of new indices.',
    },
    composed_of: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Component templates, merged in this order.',
    },
    priority: {
      type: 'Optional[Integer[0]]',
      desc: 'Templates with a higher priority win when several match an index.',
    },
    version: {
      type: 'Optional[Integer[0]]',
      desc: 'A version number for your own bookkeeping.',
    },
    meta: {
      type: 'Optional[Hash]',
      desc: 'Free-form metadata (`_meta` in the API).',
    },
    data_stream: {
      type: 'Optional[Hash]',
      desc: 'Makes the template create data streams; `{}` uses the default timestamp field `@timestamp`.',
    },
  },
)
