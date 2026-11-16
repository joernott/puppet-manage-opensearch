# The example "Data streams" from EXAMPLES.md.
opensearch_role { 'metrics_writer':
  description         => 'Write access to the metrics* indices',
  cluster_permissions => ['indices:data/write/bulk'],
  index_permissions   => [
    {
      index_patterns  => ['metrics*'],
      allowed_actions => ['write', 'create_index', 'indices:admin/mapping/put'],
    },
  ],
}

opensearch_internal_user { 'metrics':
  password    => Sensitive('Kv7-ruQ2-mzt8'),
  description => 'Java applications that write metrics',
}

opensearch_role_mapping { 'metrics_writer':
  users   => ['metrics'],
  require => Opensearch_internal_user['metrics'],
}

opensearch_ism_policy { 'metrics_daily':
  description   => 'Daily rollover, deletion after 30 days',
  default_state => 'hot',
  states        => [
    {
      'name'        => 'hot',
      'actions'     => [{ 'rollover' => { 'min_index_age' => '1d' } }],
      'transitions' => [{ 'state_name' => 'delete', 'conditions' => { 'min_index_age' => '30d' } }],
    },
    {
      'name'        => 'delete',
      'actions'     => [{ 'delete' => {} }],
      'transitions' => [],
    },
  ],
  ism_template  => [{ 'index_patterns' => ['metrics'], 'priority' => 100 }],
}

opensearch_index_template { 'metrics':
  index_patterns => ['metrics'],
  data_stream    => {},
  priority       => 100,
  template       => {
    'settings' => { 'number_of_shards' => 1, 'number_of_replicas' => 0 },
  },
}

opensearch_data_stream { 'metrics':
  require => Opensearch_ism_policy['metrics_daily'],
}
