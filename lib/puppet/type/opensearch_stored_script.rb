# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_stored_script',
  docs: <<~DOC,
    @summary Manages a stored script or search template.

    A search template (`lang => 'mustache'`) may be given as a Hash; it is
    compared with the stored template as data, not as text. Attributes that
    are not set are kept as they are in the cluster. The title is either the
    ID or `connection/ID`.

    @example A Painless script, compiled for the score context when stored
      opensearch_stored_script { 'boost_by_popularity':
        lang    => 'painless',
        source  => "_score * Math.log(2 + doc['popularity'].value)",
        context => 'score',
      }

    @example A search template
      opensearch_stored_script { 'find_by_host':
        lang   => 'mustache',
        source => {
          'query' => { 'term' => { 'host.name' => '{{host}}' } },
          'size'  => '{{size}}',
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
      desc: 'Whether the script should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The ID of the script.',
      behaviour: :namevar,
    },
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
      default: 'default',
    },
    lang: {
      type: 'Optional[String[1]]',
      desc: 'The script language, e.g. `painless` or `mustache`. Required when creating the script.',
    },
    source: {
      type: 'Optional[Variant[String[1], Hash]]',
      desc: 'The script. For `mustache`, a Hash with the search request or a JSON string. Required when creating the script.',
    },
    context: {
      type: 'Optional[String[1]]',
      desc: 'A script context such as `score` or `filter`. If set, OpenSearch compiles the script when storing it and rejects invalid scripts. Not stored, so not compared.',
      behaviour: :parameter,
    },
  },
)
