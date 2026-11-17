# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_ingest_pipeline',
  docs: <<~DOC,
    @summary Manages an ingest pipeline.

    Processors are compared exactly, in their order. Attributes that are not
    set are kept as they are in the cluster. The title is either the ID or
    `connection/ID`.

    @example
      opensearch_ingest_pipeline { 'metrics_enrich':
        description => 'Adds the environment and parses the level',
        processors  => [
          { 'set' => { 'field' => 'environment', 'value' => 'production' } },
          { 'lowercase' => { 'field' => 'level', 'ignore_missing' => true } },
        ],
        on_failure  => [
          { 'set' => { 'field' => 'ingest_error', 'value' => '{{ _ingest.on_failure_message }}' } },
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
    processors: {
      type: 'Optional[Array[Hash[String[1], Hash], 1]]',
      desc: 'The processors, in the order they run. Required when creating the pipeline.',
    },
    on_failure: {
      type: 'Optional[Array[Hash[String[1], Hash]]]',
      desc: 'Processors that run when a processor fails.',
    },
    version: {
      type: 'Optional[Integer[0]]',
      desc: 'A version number for your own bookkeeping.',
    },
  },
)
