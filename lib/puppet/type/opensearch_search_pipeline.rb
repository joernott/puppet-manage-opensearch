# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_search_pipeline',
  docs: <<~DOC,
    @summary Manages a search pipeline.

    Processors are compared exactly, in their order. Attributes that are not
    set are kept as they are in the cluster. The title is either the ID or
    `connection/ID`.

    @example
      opensearch_search_pipeline { 'public_only':
        description        => 'Only returns public documents',
        request_processors => [
          { 'filter_query' => { 'query' => { 'term' => { 'visibility' => 'public' } } } },
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
      desc: 'Whether the pipeline should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The ID of the pipeline.',
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
      desc: 'A description of the pipeline.',
    },
    request_processors: {
      type: 'Optional[Array[Hash[String[1], Hash]]]',
      desc: 'Processors that change the search request, in the order they run.',
    },
    response_processors: {
      type: 'Optional[Array[Hash[String[1], Hash]]]',
      desc: 'Processors that change the search response, in the order they run.',
    },
    phase_results_processors: {
      type: 'Optional[Array[Hash[String[1], Hash]]]',
      desc: 'Processors that run between the query and fetch phases, e.g. `normalization-processor` for hybrid search.',
    },
    version: {
      type: 'Optional[Integer[0]]',
      desc: 'A version number for your own bookkeeping.',
    },
  },
)
