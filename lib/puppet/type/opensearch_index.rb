# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_index',
  docs: <<~DOC,
    @summary Manages a single index: its existence, settings, mappings and
    whether it is open.

    Prefer index templates and data streams for indices that are created
    continuously; use this type for single, long-lived indices.

    * `settings` and `mappings` are in sync when everything they contain is
      present in the index with the same value. Settings may be nested or
      dotted, with or without the `index.` prefix.
    * Changed settings are updated in place. Static settings (e.g. `codec`)
      can only be changed on a closed index: set `state => closed`, and the
      index is closed before the settings are changed. `number_of_shards`
      can never be changed.
    * New mapping fields are added; the type of an existing field cannot be
      changed (OpenSearch rejects it).
    * Aliases are managed with `opensearch_alias`.
    * **`ensure => absent` deletes the index and its data**, and so does
      purging. Indices starting with a dot (system indices, backing indices
      of data streams) and hidden indices are not listed or purged.

    The title is either the index name or `connection/name`.

    @example
      opensearch_index { 'customers':
        settings => { 'number_of_shards' => 1, 'number_of_replicas' => 1, 'refresh_interval' => '5s' },
        mappings => {
          'dynamic'    => 'strict',
          'properties' => {
            'name'  => { 'type' => 'text' },
            'email' => { 'type' => 'keyword' },
          },
        },
      }
  DOC
  features: ['canonicalize', 'custom_insync', 'simple_get_filter'],
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
      desc: 'Whether the index should exist. `absent` deletes its data.',
      default: 'present',
    },
    name: {
      type: 'Pattern[/\A[^*,"<>|\/\\\\? #A-Z]+\z/]',
      desc: 'The name of the index: lowercase, without spaces and the characters * , " < > | / \\ ? #.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    state: {
      type: 'Optional[Enum[open, closed]]',
      desc: 'Whether the index is open or closed. A closed index cannot be read or written.',
    },
    settings: {
      type: 'Optional[Hash]',
      desc: 'Index settings. Only the settings given here are compared.',
    },
    mappings: {
      type: 'Optional[Hash]',
      desc: 'Mappings (`properties`, `dynamic`, ...). Only the mappings given here are compared.',
    },
  },
)
