# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_alias',
  docs: <<~DOC,
    @summary Manages an index alias.

    Changes are made in one atomic `_aliases` request: an alias never points
    to no index or to both the old and the new one. `filter`, the routing
    values and `is_hidden` apply to all indices of the alias.

    Don't manage aliases that ISM rolls over (`rollover_alias`): ISM moves
    the write index and Puppet would move it back. Aliases whose name starts
    with a dot are not listed. The title is either the alias name or
    `connection/name`.

    @example
      opensearch_alias { 'orders':
        indices     => ['orders-2025', 'orders-2026'],
        write_index => 'orders-2026',
      }

      opensearch_alias { 'orders-eu':
        indices => ['orders-2025', 'orders-2026'],
        filter  => { 'term' => { 'region' => 'eu' } },
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
    opensearch_index: ['$indices', '$write_index'],
  },
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether the alias should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the alias.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    indices: {
      type: 'Optional[Array[Pattern[/\A[^*,]+\z/], 1]]',
      desc: 'The indices the alias points to; names, no wildcards. The order does not matter. Required when creating the alias.',
    },
    write_index: {
      type: 'Optional[String[1]]',
      desc: 'The index that receives writes to the alias. Must be one of `indices`.',
    },
    filter: {
      type: 'Optional[Hash]',
      desc: 'A query that limits the documents visible through the alias.',
    },
    index_routing: {
      type: 'Optional[String[1]]',
      desc: 'Routing value for writes through the alias.',
    },
    search_routing: {
      type: 'Optional[String[1]]',
      desc: 'Routing values (comma-separated) for searches through the alias.',
    },
    is_hidden: {
      type: 'Optional[Boolean]',
      desc: 'Whether the alias is left out of wildcard expressions.',
    },
  },
)
