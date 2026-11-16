# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_data_stream',
  docs: <<~DOC,
    @summary Manages a data stream.

    Creating a data stream needs an index template with `data_stream` whose
    `index_patterns` match the name. The data stream automatically depends on
    an `opensearch_index_template` with the same name. An ISM policy whose
    `ism_template` matches the data stream name must exist before the data
    stream, so that it applies to the first backing index; add a `require`.

    Creating the data stream in advance means that the applications that
    write to it only need write permissions, not `indices:admin/create`.

    **`ensure => absent` deletes the data stream with all its backing indices
    and data.** So does purging with `resources`, for every data stream not in
    the catalog, including those that applications created themselves. Data
    streams whose name starts with a dot are not listed.

    The title is either the name or `connection/name`.

    @example
      opensearch_data_stream { 'metrics':
        require => Opensearch_ism_policy['metrics_daily'],
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
    opensearch_index_template: '$name',
  },
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether the data stream should exist. `absent` deletes all its data.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the data stream.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    template: {
      type: 'Optional[String]',
      desc: 'The index template the data stream was created from (read only).',
      behaviour: :read_only,
    },
    generation: {
      type: 'Optional[Integer]',
      desc: 'The number of the current backing index, i.e. rollovers + 1 (read only).',
      behaviour: :read_only,
    },
  },
)
