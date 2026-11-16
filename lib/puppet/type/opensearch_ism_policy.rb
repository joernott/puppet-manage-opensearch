# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_ism_policy',
  docs: <<~DOC,
    @summary Manages an Index State Management (ISM) policy.

    OpenSearch adds defaults to stored policies (e.g. `retry` settings for
    every action). `states`, `ism_template` and `error_notification` are
    therefore in sync when everything the manifest specifies is present in
    the cluster with the same value. Extra keys added by the server are
    ignored. Lists must have the same length and order.

    Updating a policy does not change indices that are already managed by an
    older version of it. The title is either the policy id or
    `connection/policy_id`.

    @example
      opensearch_ism_policy { 'logs_retention':
        description   => 'Delete log indices after 30 days',
        default_state => 'hot',
        states        => [
          {
            'name'        => 'hot',
            'actions'     => [{ 'rollover' => { 'min_size' => '10gb' } }],
            'transitions' => [{ 'state_name' => 'delete', 'conditions' => { 'min_index_age' => '30d' } }],
          },
          { 'name' => 'delete', 'actions' => [{ 'delete' => {} }], 'transitions' => [] },
        ],
        ism_template  => [{ 'index_patterns' => ['logs-*'], 'priority' => 100 }],
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
  },
  attributes: {
    ensure: {
      type: 'Enum[present, absent]',
      desc: 'Whether the ISM policy should exist.',
      default: 'present',
    },
    name: {
      type: 'String[1]',
      desc: 'The name of the ISM policy.',
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
      desc: 'A description of the policy.',
    },
    default_state: {
      type: 'Optional[String[1]]',
      desc: 'The state new indices start in. Required when creating the policy.',
    },
    states: {
      type: 'Optional[Array[Hash, 1]]',
      desc: 'The states with their actions and transitions, as in the ISM API.',
    },
    ism_template: {
      type: 'Optional[Array[Hash]]',
      desc: 'Index patterns (with priority) whose new indices get this policy automatically.',
    },
    error_notification: {
      type: 'Optional[Hash]',
      desc: 'Where to send a notification when a managed index fails.',
    },
  },
)
